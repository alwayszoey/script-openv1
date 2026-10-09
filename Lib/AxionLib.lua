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

local HUB_VERSION = "v22"
local WHITE = Color3.new(1, 1, 1)
local SIDEBAR_WIDTH = 150
local CORNER_RADIUS = 12
local CONFIG_FOLDER = "AxionHub"
local CONFIG_FILE = "AxionHub/config.json"
local RELOAD_FILE = "AxionHub.lua"
local LOGO_URL = "https://raw.githubusercontent.com/alwayszoey/script-openv1/refs/heads/main/assets/Untitled27_20261009042444.png"
local LOGO_FILE = "AxionHub/logo.png"
local ICONS_URL = "https://raw.githubusercontent.com/alwayszoey/script-openv1/refs/heads/main/assets/dist/Icons.lua"
local ICONS_CACHE = "AxionHub/icons.lua"
local ICON_WAIT = 4
local GRAPH_BARS = 48
local IDLE_PULSE_MIN = 90
local IDLE_PULSE_MAX = 180
local TOGGLE_KEY = Enum.KeyCode.RightShift
local PERSIST_KEYS = {
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
	Home = "rbxassetid://10723407389",
	Users = "rbxassetid://10709818534",
	Gamepad = "rbxassetid://10709818534",
	Hop = "rbxassetid://10723404337",
	Link = "rbxassetid://10709812159",
}

local rawIcons = {}

local function getIcon(input, fallback)
	if type(input) == "number" then
		return "rbxassetid://" .. input
	end

	if type(input) ~= "string" or input == "" then
		return fallback or ""
	end

	if input:find("rbxassetid://", 1, true) or input:find("http", 1, true) then
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
	if isfile and readfile and isfile(ICONS_CACHE) then
		local ok, source = pcall(readfile, ICONS_CACHE)
		if ok and parseIconSource(source) then
			return true
		end
	end

	local ok, response = pcall(request, { Url = ICONS_URL, Method = "GET" })
	if not ok or not response or not response.Success or not parseIconSource(response.Body) then
		return false
	end

	pcall(function()
		if makefolder and isfolder and not isfolder(CONFIG_FOLDER) then
			makefolder(CONFIG_FOLDER)
		end
		writefile(ICONS_CACHE, response.Body)
	end)

	return true
end

local ICON_NAMES = {
	Dashboard = "layout-dashboard",
	Settings = "settings",
	Server = "server",
	Sound = "volume-2",
	SoundMute = "volume-x",
	Bell = "bell",
	Check = "check",
	Close = "x",
	Minimize = "minimize-2",
	Copy = "copy",
	Refresh = "refresh-cw",
	Zap = "zap",
	Skull = "skull",
	Save = "save",
	Teleport = "map-pin",
	Visuals = "eye",
	Combat = "shield",
	Palette = "palette",
	Info = "info",
	Home = "home",
	Users = "users",
	Gamepad = "gamepad-2",
	Hop = "shuffle",
	Link = "link",
}

local function applyIconNames()
	for key, name in pairs(ICON_NAMES) do
		Icons[key] = getIcon(name, Icons[key])
	end
end

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
local marketplaceService = cloneRef(game:GetService("MarketplaceService"))
local statsService = cloneRef(game:GetService("Stats"))

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

local State = {
	page = "HOME",

	antiAfk = true,
	autoReconnect = true,
	autoResume = true,
	lowPower = false,
	antiKick = true,
	safeMode = true,
	reconnecting = false,
	reconnects = 0,
	reloadQueued = false,
	startTime = os.clock(),
	origFps = 60,

	uiSound = true,

	minimized = false,
	animating = false,

	frameCount = 0,
	hopping = false,
}

local uiRefs = {}
local notify = function() end

local function randomName()
	local chars = {}
	for index = 1, math.random(10, 16) do
		chars[index] = string.char(math.random(97, 122))
	end
	return table.concat(chars)
end

local function jitter(base)
	if not State.safeMode then
		return base
	end

	return base * (0.8 + math.random() * 0.5)
end

local function formatTime(seconds)
	seconds = math.floor(seconds)
	return string.format("%02d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
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

local function safeFind(root, ...)
	local node = root

	for _, name in ipairs({ ... }) do
		if not node then
			return nil
		end

		node = node:FindFirstChild(name)
	end

	return node
end

local function track(connection)
	table.insert(AxionHub.connections, connection)
	return connection
end

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

local function saveConfig()
	if not writefile then
		return
	end

	local data = {}
	for _, key in ipairs(PERSIST_KEYS) do
		data[key] = State[key]
	end

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
end


local function pulseIdle()
	pcall(function()
		virtualUser:CaptureController()
		virtualUser:ClickButton2(Vector2.new(math.random(1, 50), math.random(1, 50)))
	end)
end

local function initAntiAfk()
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

local function applyLowPower(on)
	pcall(function()
		runService:Set3dRenderingEnabled(not on)
	end)

	if setfpscap then
		pcall(setfpscap, on and 15 or State.origFps)
	end
end

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

local function getGreeting(hour)
	if hour >= 5 and hour < 12 then
		return "Good morning"
	end

	if hour >= 12 and hour < 18 then
		return "Good afternoon"
	end

	return "Good evening"
end

local function getPing()
	local ok, value = pcall(function()
		return statsService.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)

	if ok and type(value) == "number" then
		return value
	end

	local okPing, ping = pcall(function()
		return localPlayer:GetNetworkPing() * 2000
	end)

	return okPing and ping or 0
end

local function serverHop()
	if State.hopping then
		return
	end

	State.hopping = true
	notify("Searching for a server...", Config.muted)

	task.spawn(function()
		local target
		local cursor

		for _ = 1, 3 do
			local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
			if cursor then
				url = url .. "&cursor=" .. cursor
			end

			local ok, response = pcall(request, { Url = url, Method = "GET" })
			if not ok or not response or not response.Success then
				break
			end

			local decoded, data = pcall(function()
				return httpService:JSONDecode(response.Body)
			end)
			if not decoded or type(data) ~= "table" or type(data.data) ~= "table" then
				break
			end

			local candidates = {}
			for _, server in ipairs(data.data) do
				if server.id ~= game.JobId and server.playing and server.maxPlayers and server.playing < server.maxPlayers then
					table.insert(candidates, server)
				end
			end

			if #candidates > 0 then
				target = candidates[math.random(1, #candidates)]
				break
			end

			cursor = data.nextPageCursor
			if not cursor then
				break
			end
		end

		if not target then
			State.hopping = false
			notify("No server found", Config.bad)
			return
		end

		saveConfig()
		notify("Hopping server...", Config.good)

		local ok = pcall(function()
			teleportService:TeleportToPlaceInstance(game.PlaceId, target.id, localPlayer)
		end)

		if not ok then
			notify("Teleport failed", Config.bad)
		end

		task.delay(10, function()
			State.hopping = false
		end)
	end)
end

local function rejoinServer()
	if State.hopping then
		return
	end

	State.hopping = true
	saveConfig()
	notify("Rejoining...", Config.good)

	local ok = pcall(function()
		if #playersService:GetPlayers() <= 1 then
			teleportService:Teleport(game.PlaceId, localPlayer)
		else
			teleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, localPlayer)
		end
	end)

	if not ok then
		notify("Rejoin failed", Config.bad)
	end

	task.delay(10, function()
		State.hopping = false
	end)
end

local function copyServerLink()
	if not setclipboard then
		notify("Clipboard not supported", Config.bad)
		return
	end

	if game.JobId == "" then
		notify("No server id here", Config.bad)
		return
	end

	local link = string.format("https://www.roblox.com/games/start?placeId=%d&gameInstanceId=%s", game.PlaceId, game.JobId)
	setclipboard(link)
	notify("Copied server link", Config.good)
end

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
	label.Font = font or Config.font
	label.TextSize = textSize or 11
	label.TextColor3 = color or Config.text
	label.BackgroundTransparency = 1
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.ZIndex = 5
	label.Parent = parent
	return label
end

local currentLogo = Icons.Logo
local logoLabels = {}

local function registerLogo(label)
	table.insert(logoLabels, label)
	label.Image = currentLogo
	return label
end

local function setLogo(asset)
	currentLogo = asset

	for _, label in ipairs(logoLabels) do
		if label.Parent then
			label.Image = asset
		end
	end
end

local function resolveCachedLogo()
	if not (getcustomasset and isfile and isfile(LOGO_FILE)) then
		return nil
	end

	local ok, asset = pcall(getcustomasset, LOGO_FILE)
	return ok and asset or nil
end

local Loading = {
	gui = nil,
	root = nil,
	logo = nil,
	stepLabel = nil,
	connection = nil,
	progress = 0,
	targetProgress = 0,
}

local function getLoadingScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	return math.clamp(math.min(viewport.X * 0.9 / 340, viewport.Y * 0.8 / 240, 1), 0.5, 1)
end

local function createLoadingScreen()
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
	createGradient(overlay, 115, ColorSequence.new(Config.bgTop, Config.bgBot))

	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(0, 320, 0, 220)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0.5, 0, 0.5, 0)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.ZIndex = 2
	holder.Parent = root

	local holderScale = Instance.new("UIScale")
	holderScale.Scale = getLoadingScale()
	holderScale.Parent = holder

	local glow = Instance.new("ImageLabel")
	glow.Size = UDim2.new(1, 70, 1, 70)
	glow.Position = UDim2.new(0, -35, 0, -35)
	glow.BackgroundTransparency = 1
	glow.Image = "rbxassetid://5028857084"
	glow.ImageColor3 = Config.accentPink
	glow.ImageTransparency = 0.6
	glow.ScaleType = Enum.ScaleType.Slice
	glow.SliceCenter = Rect.new(24, 24, 276, 276)
	glow.ZIndex = 2
	glow.Parent = holder

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 1, 0)
	card.BackgroundColor3 = WHITE
	card.BackgroundTransparency = 0.03
	card.BorderSizePixel = 0
	card.ZIndex = 3
	card.Parent = holder
	createCorner(card, 18)
	createGradient(card, 110, ColorSequence.new(Config.bgTop, Config.bgBot))
	createStroke(card, 1.5, 0.35)

	local logo = makeIcon(card, currentLogo, UDim2.new(0, 72, 0, 72), UDim2.new(0.5, -36, 0, 20), WHITE)
	logo.ScaleType = Enum.ScaleType.Fit
	logo.ZIndex = 5
	registerLogo(logo)

	local logoScale = Instance.new("UIScale")
	logoScale.Parent = logo

	local nameLabel = makeLabel(card, "AxionHub", UDim2.new(1, -40, 0, 26), UDim2.new(0, 20, 0, 100), Config.fontBold, 20, Config.text, Enum.TextXAlignment.Center)
	nameLabel.ZIndex = 5

	local barTrack = Instance.new("Frame")
	barTrack.Size = UDim2.new(1, -80, 0, 8)
	barTrack.Position = UDim2.new(0, 40, 0, 146)
	barTrack.BackgroundColor3 = Config.track
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
	local fillGradient = createGradient(fill, 0, accentSequence())

	local stepLabel = makeLabel(card, "Starting...", UDim2.new(1, -40, 0, 16), UDim2.new(0, 20, 0, 164), Config.fontMedium, 11, Config.textDim, Enum.TextXAlignment.Center)
	stepLabel.ZIndex = 5

	local percent = makeLabel(card, "0%", UDim2.new(1, -40, 0, 14), UDim2.new(0, 20, 0, 184), Config.font, 10, Config.muted, Enum.TextXAlignment.Center)
	percent.ZIndex = 5

	Loading.gui = gui
	Loading.root = root
	Loading.logo = logo
	Loading.stepLabel = stepLabel

	Loading.connection = runService.Heartbeat:Connect(function(dt)
		local diff = Loading.targetProgress - Loading.progress
		Loading.progress = Loading.progress + diff * math.min(dt * 6, 1)

		fill.Size = UDim2.new(math.clamp(Loading.progress, 0, 1), 0, 1, 0)
		percent.Text = string.format("%d%%", math.floor(Loading.progress * 100 + 0.5))

		local now = os.clock()
		logoScale.Scale = 1 + math.sin(now * 3) * 0.04
		fillGradient.Offset = Vector2.new(math.sin(now * 2) * 0.25, 0)
		holderScale.Scale = getLoadingScale()
	end)

	tween(root, 0.3, { GroupTransparency = 0 })
end

local function setStep(text, progress)
	if not Loading.gui then
		return
	end

	Loading.stepLabel.Text = text
	Loading.targetProgress = progress
end

local function cleanupLoading()
	if Loading.connection then
		Loading.connection:Disconnect()
		Loading.connection = nil
	end

	if Loading.gui then
		pcall(function()
			Loading.gui:Destroy()
		end)
		Loading.gui = nil
	end

	Loading.root = nil
end

local function destroyLoadingScreen()
	if not Loading.gui then
		return
	end

	Loading.targetProgress = 1

	task.spawn(function()
		local deadline = os.clock() + 1

		while Loading.progress < 0.97 and os.clock() < deadline do
			task.wait()
		end

		if Loading.root then
			tween(Loading.root, 0.4, { GroupTransparency = 1 })
		end

		task.wait(0.45)
		cleanupLoading()
	end)
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
	local resolvedIcon = iconImage and getIcon(iconImage) or nil
	if resolvedIcon and resolvedIcon ~= "" then
		icon = makeIcon(row, resolvedIcon, UDim2.new(0, 18, 0, 18), UDim2.new(0, 14, 0.5, -9), Config.accentLight)
	end

	makeLabel(row, title, UDim2.new(0.7, 0, 1, 0), UDim2.new(0, icon and 40 or 14, 0, 0), Config.fontMedium, 12, Config.text)

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

local function buildHomePage(page)
	local homeHeader = makeCard(page, UDim2.new(1, -120, 0, 50), UDim2.new(0, 18, 0, 16))

	makeIcon(homeHeader, Icons.Home, UDim2.new(0, 20, 0, 20), UDim2.new(0, 14, 0.5, -10), Config.accentLight)

	local greetingLabel = makeLabel(homeHeader, "", UDim2.new(0, 150, 0, 14), UDim2.new(0, 44, 0, 8), Config.font, 10, Config.accentLight)
	local playerLabel = makeLabel(homeHeader, localPlayer.Name, UDim2.new(0, 150, 0, 20), UDim2.new(0, 44, 0, 22), Config.fontBold, 14, Config.text)
	playerLabel.TextTruncate = Enum.TextTruncate.AtEnd

	local timeLabel = makeLabel(homeHeader, "", UDim2.new(0, 92, 0, 18), UDim2.new(1, -104, 0, 8), Config.fontBold, 15, Config.text, Enum.TextXAlignment.Right)
	local dateLabel = makeLabel(homeHeader, "", UDim2.new(0, 92, 0, 12), UDim2.new(1, -104, 0, 28), Config.font, 9, Config.muted, Enum.TextXAlignment.Right)

	local gameCard = makeCard(page, UDim2.new(1, -36, 0, 76), UDim2.new(0, 18, 0, 72))

	local gameThumb = game.GameId ~= 0 and string.format("rbxthumb://type=GameIcon&id=%d&w=420&h=420", game.GameId) or Icons.Gamepad

	local gameIcon = makeIcon(gameCard, gameThumb, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), WHITE)
	gameIcon.ScaleType = Enum.ScaleType.Crop
	gameIcon.ImageTransparency = 0.72
	gameIcon.ZIndex = 4
	createCorner(gameIcon, CORNER_RADIUS)

	local gameShade = Instance.new("Frame")
	gameShade.Size = UDim2.new(1, 0, 1, 0)
	gameShade.BackgroundColor3 = Color3.new(0, 0, 0)
	gameShade.BorderSizePixel = 0
	gameShade.ZIndex = 5
	gameShade.Parent = gameCard
	createCorner(gameShade, CORNER_RADIUS)

	local shadeGradient = Instance.new("UIGradient")
	shadeGradient.Rotation = 0
	shadeGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 0.55),
	})
	shadeGradient.Parent = gameShade

	local smallIcon = makeIcon(gameCard, gameThumb, UDim2.new(0, 56, 0, 56), UDim2.new(0, 10, 0.5, -28), WHITE)
	smallIcon.ScaleType = Enum.ScaleType.Crop
	smallIcon.ZIndex = 7
	createCorner(smallIcon, 10)
	createStroke(smallIcon, 1, 0.5)

	local gameNameLabel = makeLabel(gameCard, "Loading...", UDim2.new(1, -90, 0, 18), UDim2.new(0, 76, 0, 10), Config.fontBold, 14, Config.text)
	gameNameLabel.TextTruncate = Enum.TextTruncate.AtEnd

	local placeLabel = makeLabel(gameCard, "Place ID  " .. game.PlaceId, UDim2.new(1, -90, 0, 12), UDim2.new(0, 76, 0, 32), Config.fontMedium, 10, Config.textDim)

	local usersIcon = makeIcon(gameCard, Icons.Users, UDim2.new(0, 12, 0, 12), UDim2.new(0, 76, 0, 51), Config.good)
	usersIcon.ZIndex = 7
	local playersLabel = makeLabel(gameCard, "", UDim2.new(1, -110, 0, 12), UDim2.new(0, 94, 0, 51), Config.fontMedium, 10, Config.good)

	for _, label in ipairs({ gameNameLabel, placeLabel, playersLabel }) do
		label.ZIndex = 7
		label.TextStrokeTransparency = 0.75
	end

	task.spawn(function()
		local ok, info = pcall(function()
			return marketplaceService:GetProductInfo(game.PlaceId)
		end)

		if not AxionHub.alive then
			return
		end

		if not ok or type(info) ~= "table" then
			gameNameLabel.Text = "Unknown game"
			return
		end

		gameNameLabel.Text = info.Name or "Unknown game"

		local iconId = tonumber(info.IconImageAssetId)
		if iconId and iconId > 0 then
			local assetUrl = getIcon("rbxassetid://" .. iconId)
			gameIcon.Image = assetUrl
			smallIcon.Image = assetUrl
		end
	end)

	local statsCard = makeCard(page, UDim2.new(1, -36, 0, 120), UDim2.new(0, 18, 0, 154))

	makeLabel(statsCard, "SYSTEM & PERFORMANCE", UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 8), Config.fontBold, 9.5, Config.accentLight)

	local function makeStat(index, title, value)
		local tile = Instance.new("Frame")
		tile.Size = UDim2.new(0, 88, 0, 36)
		tile.Position = UDim2.new(0, 14 + (index - 1) * 96, 0, 26)
		tile.BackgroundColor3 = Config.chipOff
		tile.BorderSizePixel = 0
		tile.ZIndex = 4
		tile.Parent = statsCard
		createCorner(tile, 8)

		makeLabel(tile, title, UDim2.new(1, -16, 0, 10), UDim2.new(0, 8, 0, 5), Config.fontBold, 8.5, Config.muted)

		local valueLabel = makeLabel(tile, value, UDim2.new(1, -16, 0, 16), UDim2.new(0, 8, 0, 16), Config.fontBold, 11.5, Config.text)
		valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
		return valueLabel
	end

	makeStat(1, "PLAYER", localPlayer.Name)
	local uptimeValue = makeStat(2, "UPTIME", "00:00:00")
	local fpsValue = makeStat(3, "FPS", "--")
	local pingValue = makeStat(4, "PING", "--")

	local graph = Instance.new("Frame")
	graph.Size = UDim2.new(1, -28, 0, 44)
	graph.Position = UDim2.new(0, 14, 0, 68)
	graph.BackgroundColor3 = Config.track
	graph.BorderSizePixel = 0
	graph.ClipsDescendants = true
	graph.ZIndex = 4
	graph.Parent = statsCard
	createCorner(graph, 8)

	local graphLabel = makeLabel(graph, "FPS", UDim2.new(0, 30, 0, 10), UDim2.new(0, 6, 0, 3), Config.fontBold, 8, Config.muted)
	graphLabel.ZIndex = 7

	local bars = {}
	local history = {}

	for index = 1, GRAPH_BARS do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Size = UDim2.new(1 / GRAPH_BARS, -1, 0, 0)
		bar.Position = UDim2.new((index - 1) / GRAPH_BARS, 1, 1, -2)
		bar.BackgroundColor3 = Config.accentLight
		bar.BorderSizePixel = 0
		bar.ZIndex = 5
		bar.Parent = graph
		createCorner(bar, 2)

		bars[index] = bar
		history[index] = 0
	end

	local function fpsColor(value)
		if value >= 50 then
			return Config.good
		end

		if value >= 30 then
			return Config.accentLight
		end

		return Config.bad
	end

	local function pushFps(fps)
		table.remove(history, 1)
		table.insert(history, fps)

		local peak = 60
		for _, value in ipairs(history) do
			peak = math.max(peak, value)
		end

		for index, bar in ipairs(bars) do
			local value = history[index]
			local height = math.clamp(value / peak * 38, value > 0 and 2 or 0, 38)
			bar.Size = UDim2.new(1 / GRAPH_BARS, -1, 0, height)
			bar.BackgroundColor3 = fpsColor(value)
		end
	end

	local actionsCard = makeCard(page, UDim2.new(1, -36, 0, 62), UDim2.new(0, 18, 0, 280))

	makeLabel(actionsCard, "QUICK ACTIONS", UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 6), Config.fontBold, 9.5, Config.accentLight)

	local actionX = 14

	local function makeAction(text, width, icon, callback)
		local chip = makeChip(actionsCard, UDim2.new(0, width, 0, 30), UDim2.new(0, actionX, 0, 24), text, 10, 999)
		actionX = actionX + width + 12

		chip.label.Position = UDim2.new(0, 22, 0, 0)
		chip.label.Size = UDim2.new(1, -28, 1, 0)
		makeIcon(chip.button, icon, UDim2.new(0, 14, 0, 14), UDim2.new(0, 12, 0.5, -7), Config.text)
		addHover(chip)

		track(chip.button.MouseButton1Click:Connect(function()
			playSound("Click")
			styleChip(chip, true)

			task.delay(0.3, function()
				if AxionHub.alive then
					styleChip(chip, false)
				end
			end)

			callback()
		end))
	end

	makeAction("Server Hop", 108, Icons.Hop, serverHop)
	makeAction("Rejoin", 92, Icons.Refresh, rejoinServer)
	makeAction("Copy Server Link", 152, Icons.Link, copyServerLink)

	local function refreshInfo(fps)
		local now = os.date("*t")
		greetingLabel.Text = getGreeting(now.hour)
		timeLabel.Text = os.date("%H:%M")
		dateLabel.Text = os.date("%a, %d %b")

		playersLabel.Text = string.format("%d / %d players", #playersService:GetPlayers(), playersService.MaxPlayers)
		uptimeValue.Text = formatTime(time())

		local ping = getPing()
		pingValue.Text = string.format("%d ms", math.floor(ping + 0.5))
		pingValue.TextColor3 = ping < 100 and Config.good or (ping < 200 and Config.text or Config.bad)

		if fps then
			fpsValue.Text = tostring(math.floor(fps + 0.5))
			fpsValue.TextColor3 = fpsColor(fps)
			pushFps(fps)
		end
	end

	refreshInfo()

	task.spawn(function()
		local lastFrames = State.frameCount
		local lastClock = os.clock()

		while AxionHub.alive and page.Parent do
			task.wait(0.5)

			local now = os.clock()
			local fps = (State.frameCount - lastFrames) / math.max(now - lastClock, 0.001)
			lastFrames = State.frameCount
			lastClock = now

			if not State.minimized then
				refreshInfo(fps)
			end
		end
	end)

	return homeHeader
end

local function buildUI()
	local parent = safeParent()
	local logo = currentLogo

	local gui = Instance.new("ScreenGui")
	gui.Name = randomName()
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 999
	gui.Parent = parent
	AxionHub.gui = gui

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

	registerLogo(makeIcon(miniBtn, logo, UDim2.new(1, -12, 1, -12), UDim2.new(0, 6, 0, 6)))

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

	local sidebarLogo = registerLogo(makeIcon(sidebar, logo, UDim2.new(0, 68, 0, 68), UDim2.new(0, 12, 0, 4), WHITE))
	sidebarLogo.ScaleType = Enum.ScaleType.Fit
	sidebarLogo.ZIndex = 3

	makeLabel(sidebar, "AxionHub", UDim2.new(1, -20, 0, 18), UDim2.new(0, 16, 0, 72), Config.fontBold, 15, Config.text)
	makeLabel(sidebar, "Script Hub  " .. HUB_VERSION, UDim2.new(1, -20, 0, 14), UDim2.new(0, 16, 0, 90), Config.font, 10, Config.accentLight)

	local uptimeLabel = makeLabel(sidebar, "⏱ 00:00:00", UDim2.new(1, -20, 0, 14), UDim2.new(0, 16, 1, -40), Config.fontMedium, 10.5, Config.textDim)
	local shieldLabel = makeLabel(sidebar, "● protected", UDim2.new(1, -20, 0, 12), UDim2.new(0, 16, 1, -24), Config.font, 9, Config.good)

	local pages = {
		{ id = "HOME", icon = Icons.Home, label = "Home", desc = "overview & tools" },
		{ id = "MAIN", icon = Icons.Dashboard, label = "Main", desc = "your script" },
		{ id = "SETTINGS", icon = Icons.Settings, label = "Settings", desc = "protection & sound" },
	}

	local pageButtons = {}

	for index, page in ipairs(pages) do
		local chip = makeChip(
			sidebar,
			UDim2.new(1, -24, 0, 42),
			UDim2.new(0, 12, 0, 132 + (index - 1) * 46),
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
	local homePage = makePage(content)
	local pageFrames = { HOME = homePage, MAIN = mainPage, SETTINGS = settingsPage }

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
		toastIcon.Image = getIcon(color == Config.good and Icons.Check or Icons.Bell)
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

	local homeHeader = buildHomePage(homePage)

	local header = makeCard(mainPage, UDim2.new(1, -90, 0, 42), UDim2.new(0, 18, 0, 16))

	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 8, 0, 8)
	dot.Position = UDim2.new(0, 14, 0.5, -4)
	dot.BackgroundColor3 = Config.good
	dot.BorderSizePixel = 0
	dot.ZIndex = 5
	dot.Parent = header
	createCorner(dot, 999)

	local statusLabel = makeLabel(header, "READY", UDim2.new(1, -44, 1, 0), UDim2.new(0, 30, 0, 0), Config.font, 11, Config.text)
	statusLabel.TextTruncate = Enum.TextTruncate.AtEnd

	-- Empty workspace for your own map script. Build new cards/toggles here
	-- using makeCard / makeToggle / makeChip, the same way buildHomePage does.
	local placeholderCard = makeCard(mainPage, UDim2.new(1, -36, 0, 132), UDim2.new(0, 18, 0, 70))

	makeLabel(placeholderCard, "MAIN", UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 8), Config.fontBold, 9.5, Config.accentLight)

	local placeholderHint = makeLabel(
		placeholderCard,
		"This page is empty. Add your script's features here with makeCard / makeToggle / makeChip.",
		UDim2.new(1, -28, 0, 60),
		UDim2.new(0, 14, 0, 32),
		Config.font,
		10,
		Config.muted
	)
	placeholderHint.TextWrapped = true

	local settingsHeader = makeCard(settingsPage, UDim2.new(1, -90, 0, 42), UDim2.new(0, 18, 0, 16))

	makeIcon(settingsHeader, Icons.Settings, UDim2.new(0, 16, 0, 16), UDim2.new(0, 16, 0.5, -8), Config.accentLight)
	makeLabel(settingsHeader, "Settings", UDim2.new(1, -50, 1, 0), UDim2.new(0, 40, 0, 0), Config.fontBold, 12, Config.text)

	local settingsCard = makeCard(settingsPage, UDim2.new(1, -36, 0, 296), UDim2.new(0, 18, 0, 70))

	makeLabel(settingsCard, "PROTECTION", UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 6), Config.fontBold, 9.5, Config.accentLight)

	local soundToggle
	soundToggle = makeToggle(settingsCard, 26, "UI Sounds", State.uiSound, function(value)
		State.uiSound = value
		soundToggle.icon.Image = getIcon(value and Icons.Sound or Icons.SoundMute)
		saveConfig()
	end, State.uiSound and Icons.Sound or Icons.SoundMute)

	local function addSwitch(y, title, key, icon, onChange)
		return makeToggle(settingsCard, y, title, State[key], function(value)
			State[key] = value

			if onChange then
				onChange(value)
			end

			saveConfig()
			notify(title .. (value and "  ON" or "  OFF"), value and Config.good or Config.muted)
		end, icon)
	end

	addSwitch(64, "Anti-AFK (no idle kick)", "antiAfk", Icons.Bell)
	addSwitch(102, "Auto Reconnect", "autoReconnect", Icons.Refresh)
	addSwitch(140, "Auto Resume after rejoin", "autoResume", Icons.Teleport)
	addSwitch(178, "Low Power Mode", "lowPower", Icons.Palette, applyLowPower)
	addSwitch(216, "Anti-Kick (client)", "antiKick", Icons.Combat)
	addSwitch(254, "Safe Mode (human timing)", "safeMode", Icons.Info)

	local sessionCard = makeCard(settingsPage, UDim2.new(1, -36, 0, 50), UDim2.new(0, 18, 0, 376))

	makeLabel(sessionCard, "SESSION", UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 6), Config.fontBold, 9.5, Config.accentLight)
	local sessionLabel = makeLabel(sessionCard, "", UDim2.new(1, -28, 0, 16), UDim2.new(0, 14, 0, 24), Config.fontMedium, 11, Config.text)

	local copyChip = makeChip(sessionCard, UDim2.new(0, 28, 0, 28), UDim2.new(1, -42, 0, 11), "", 10, 999)
	addHover(copyChip)
	makeIcon(copyChip.button, Icons.Copy, UDim2.new(0, 14, 0, 14), UDim2.new(0.5, -7, 0.5, -7), Config.text)

	track(copyChip.button.MouseButton1Click:Connect(function()
		playSound("Click")
		if setclipboard then
			setclipboard(sessionLabel.Text)
			notify("Copied session info", Config.good)
		end
	end))

	task.spawn(function()
		while AxionHub.alive do
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

	local blur = Instance.new("BlurEffect")
	blur.Name = randomName()
	blur.Size = 0
	blur.Parent = workspace.CurrentCamera or lighting
	AxionHub.blur = blur

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

	local draggingWindow = false
	local dragStart, startPosition

	for _, handle in ipairs({ homeHeader, header, settingsHeader }) do
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

function AxionHub.detach()
	AxionHub.alive = false

	cleanupLoading()

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

local function onHeartbeat()
	State.frameCount = State.frameCount + 1

	if State.minimized then
		return
	end

	local now = os.clock()
	for _, spinner in ipairs(AxionHub.spinners) do
		spinner.gradient.Rotation = (spinner.offset + now * spinner.speed) % 360
	end
end

local function initializeScript()
	loadConfig()

	State.startTime = os.clock()

	local okFps, fps = pcall(getfpscap)
	State.origFps = okFps and tonumber(fps) or 60

	local cachedLogo = resolveCachedLogo()
	currentLogo = cachedLogo or Icons.Logo
	createLoadingScreen()
	setStep("Starting...", 0.05)

	runService.Heartbeat:Wait()
	runService.Heartbeat:Wait()

	local iconsDone = false
	task.spawn(function()
		pcall(loadIconLibrary)
		iconsDone = true
	end)

	if not cachedLogo then
		task.spawn(function()
			local asset = resolveLogo()
			if AxionHub.alive and asset ~= Icons.Logo then
				setLogo(asset)
			end
		end)
	end

	setStep("Loading features...", 0.3)

	track(runService.Heartbeat:Connect(onHeartbeat))

	-- TODO: resolve your own map's RemoteEvents/RemoteFunctions here.

	setStep("Enabling protection...", 0.6)

	for _, step in ipairs({ initAntiAfk, initReconnect, installAntiKick }) do
		pcall(step)
	end

	setStep("Loading icons...", 0.7)

	local iconDeadline = os.clock() + ICON_WAIT
	while not iconsDone and os.clock() < iconDeadline do
		task.wait(0.05)
	end

	applyIconNames()

	setStep("Building UI...", 0.85)
	task.wait()

	buildUI()

	setStep("Ready", 1)
	destroyLoadingScreen()

	if State.lowPower then
		applyLowPower(true)
	end

	-- TODO: add your own "resume after rejoin" logic here (State.autoResume).
end

local function onInitializeError(error)
	warn("[AxionHub] Failed to initialize.")
	warn(error)
	warn(debug.traceback())
	AxionHub.detach()
end

if shared.AxionHub then
	pcall(shared.AxionHub.detach)
end

shared.AxionHub = AxionHub

xpcall(initializeScript, onInitializeError)
