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
local HUB_VERSION = "v17"
local WHITE = Color3.new(1, 1, 1)
local SIDEBAR_WIDTH = 150
local CORNER_RADIUS = 12

-- Services.
local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")
local userInputService = game:GetService("UserInputService")
local lighting = game:GetService("Lighting")
local httpService = game:GetService("HttpService")
local teleportService = game:GetService("TeleportService")
local guiService = game:GetService("GuiService")
local coreGui = game:GetService("CoreGui")
local virtualUser = game:GetService("VirtualUser")

local localPlayer = playersService.LocalPlayer

local Config = {
	-- Logo accents: blue-violet to magenta-purple.
	accentBlue = Color3.fromRGB(84, 38, 232),
	accentPink = Color3.fromRGB(172, 44, 248),
	accentLight = Color3.fromRGB(206, 164, 255),

	-- Backgrounds: near-black with a purple glow.
	bgTop = Color3.fromRGB(26, 12, 48),
	bgBot = Color3.fromRGB(4, 2, 9),
	sidebarTop = Color3.fromRGB(14, 6, 26),
	sidebarBot = Color3.fromRGB(2, 1, 5),

	-- Cards.
	cardTop = Color3.fromRGB(44, 20, 82),
	cardBot = Color3.fromRGB(14, 6, 28),

	-- Capsules.
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

-- Short mode descriptions shown under the mode capsules.
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

	tower = "Hidden Leaf Tower",
	towerBest = true,
	towerFloors = 10,
	towerDelay = 1.5,
	autoTower = false,
	towerThread = nil,
	towerRuns = 0,
	towerFloorsDone = 0,
	towerStatus = "OFF",

	autoQuest = false,
	questThread = nil,
	autoDaily = false,
	dailyThread = nil,
	claimInterval = 20,
	questSent = 0,
	dailySent = 0,

	antiAfk = true,
	autoReconnect = true,
	lowFps = false,
	defaultFps = 60,
	rejoining = false,
	reconnectStatus = "STANDBY",

	saveQueued = false,
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
	playTower = safeFind(replicatedStorage, "Network", "Towers", "RF", "PlayTower"),
	completeFloor = safeFind(replicatedStorage, "Network", "Towers", "RF", "CompleteTowerFloor"),
	cancelTower = safeFind(replicatedStorage, "Network", "Towers", "RF", "CancelTower"),
	equipBestTeam = safeFind(replicatedStorage, "Network", "Towers", "RE", "EquipBestTowerTeam"),
	questClaim = safeFind(replicatedStorage, "Network", "QuestService", "RE", "Claim"),
	dailyClaim = safeFind(replicatedStorage, "Network", "DailyRewardService", "RE", "Claim"),
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

-- Dungeon (tower) names, matches ReplicatedStorage.Assets.Models.
local TOWERS = {
	"Dragon Tower",
	"Cursed Tower",
	"Pirate Tower",
	"Hidden Leaf Tower",
	"Slayer Tower",
	"Shadow Tower",
	"Infinity Tower",
}

-- Floors per run (PlayTower takes only the name, floors = CompleteTowerFloor calls).
local MAX_FLOORS = 100

-- Config file so the script resumes itself after a rejoin.
local SAVE_FOLDER = "AxionHub"
local SAVE_PATH = "AxionHub/AutoDice.json"
local AUTOLOAD_PATH = "AxionHub/AutoDice.lua"

local Toggles = {}

---Collect every setting worth keeping.
local function snapshotConfig()
	return {
		mode = State.mode,
		spamSpeed = State.spamSpeed,
		plotMax = State.plotMax,
		bypassAnim = State.bypassAnim,
		killCutscene = State.killCutscene,
		tower = State.tower,
		towerBest = State.towerBest,
		towerFloors = State.towerFloors,
		roll = State.running,
		collect = State.autoCollect,
		autoTower = State.autoTower,
		quest = State.autoQuest,
		daily = State.autoDaily,
		antiAfk = State.antiAfk,
		autoReconnect = State.autoReconnect,
		lowFps = State.lowFps,
	}
end

---Write the config to disk (debounced).
local function saveConfig()
	if State.saveQueued or type(writefile) ~= "function" then
		return
	end

	State.saveQueued = true

	task.delay(0.5, function()
		State.saveQueued = false

		pcall(function()
			if type(isfolder) == "function" and not isfolder(SAVE_FOLDER) then
				makefolder(SAVE_FOLDER)
			end

			writefile(SAVE_PATH, httpService:JSONEncode(snapshotConfig()))
		end)
	end)
end

---Read the config from disk and apply the plain settings.
---@return table
local function loadConfig()
	local saved = {}

	if type(isfile) ~= "function" or not isfile(SAVE_PATH) then
		return saved
	end

	local ok, decoded = pcall(function()
		return httpService:JSONDecode(readfile(SAVE_PATH))
	end)

	if not ok or type(decoded) ~= "table" then
		return saved
	end

	saved = decoded

	if MODE_INFO[saved.mode] then
		State.mode = saved.mode
	end
	if type(saved.spamSpeed) == "number" and saved.spamSpeed > 0 then
		State.spamSpeed = math.clamp(saved.spamSpeed, 1 / 200, 1 / 20)
	end
	if type(saved.plotMax) == "number" then
		State.plotMax = saved.plotMax
	end
	if type(saved.bypassAnim) == "boolean" then
		State.bypassAnim = saved.bypassAnim
	end
	if type(saved.killCutscene) == "boolean" then
		State.killCutscene = saved.killCutscene
	end
	if table.find(TOWERS, saved.tower) then
		State.tower = saved.tower
	end
	if type(saved.towerBest) == "boolean" then
		State.towerBest = saved.towerBest
	end
	if type(saved.towerFloors) == "number" then
		State.towerFloors = math.clamp(math.floor(saved.towerFloors), 1, MAX_FLOORS)
	end

	return saved
end

---Press a gui button by firing its real connections (no remote args needed).
---@param button GuiButton
---@return boolean
local function pressButton(button)
	if type(getconnections) ~= "function" then
		return false
	end

	for _, signalName in ipairs({ "MouseButton1Click", "Activated" }) do
		local ok, connections = pcall(getconnections, button[signalName])
		if ok and type(connections) == "table" and #connections > 0 then
			for _, connection in ipairs(connections) do
				pcall(function()
					connection:Fire()
				end)
			end

			return true
		end
	end

	return false
end

---Find a menu frame under PlayerGui.Root.Menus.
---@param name string
---@return Instance?
local function getMenu(name)
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local root = playerGui and playerGui:FindFirstChild("Root")
	local menus = root and root:FindFirstChild("Menus")

	return menus and menus:FindFirstChild(name)
end

-- Auto Dungeon.

local towerReady = Remotes.playTower ~= nil and Remotes.completeFloor ~= nil

---Equip the best team, enter the tower, clear floors, then leave.
---@return boolean
local function runTower()
	if State.towerBest and Remotes.equipBestTeam then
		State.towerStatus = "TEAM"
		pcall(function()
			Remotes.equipBestTeam:FireServer()
		end)
		task.wait(0.4)
	end

	State.towerStatus = "ENTER"

	local ok, started = pcall(function()
		return Remotes.playTower:InvokeServer(State.tower)
	end)

	if not ok or started == false then
		State.towerStatus = "WAIT"
		return false
	end

	State.towerStatus = "CLEAR"

	for _ = 1, State.towerFloors do
		if not State.autoTower or not AxionHub.alive then
			break
		end

		local floorOk, result = pcall(function()
			return Remotes.completeFloor:InvokeServer()
		end)

		if not floorOk or result == false then
			break
		end

		State.towerFloorsDone = State.towerFloorsDone + 1
		task.wait(0.15)
	end

	if Remotes.cancelTower then
		pcall(function()
			Remotes.cancelTower:InvokeServer()
		end)
	end

	State.towerRuns = State.towerRuns + 1
	State.towerStatus = "DONE"

	return true
end

local function towerLoop()
	while State.autoTower and AxionHub.alive do
		local ok, started = pcall(runTower)
		task.wait((ok and started) and State.towerDelay or 3)
	end
end

local function startTower()
	if State.autoTower or not towerReady then
		return
	end

	State.autoTower = true
	State.towerThread = task.spawn(towerLoop)
end

local function stopTower()
	State.autoTower = false
	State.towerStatus = "OFF"

	if State.towerThread then
		pcall(task.cancel, State.towerThread)
		State.towerThread = nil
	end
end

-- Auto Quest / Daily claim.

---Claim every finished quest row.
local function claimQuests()
	local menu = getMenu("Quests")
	local list = menu and menu:FindFirstChild("ScrollingFrame", true)

	if not list then
		return
	end

	for _, entry in ipairs(list:GetChildren()) do
		if not entry:IsA("Frame") or entry.Name == "Template" then
			continue
		end

		local buttons = entry:FindFirstChild("Buttons")
		local claim = buttons and buttons:FindFirstChild("Claim")
		if not claim or not claim.Visible then
			continue
		end

		-- Fall back to the remote with the quest id when gui has no connection.
		if not pressButton(claim) and Remotes.questClaim then
			pcall(function()
				Remotes.questClaim:FireServer(entry.Name)
			end)
		end

		State.questSent = State.questSent + 1
		task.wait(0.3)
	end
end

---Claim the daily reward (remote takes no arguments, confirmed by spy).
local function claimDaily()
	if Remotes.dailyClaim then
		pcall(function()
			Remotes.dailyClaim:FireServer()
		end)

		State.dailySent = State.dailySent + 1
		return
	end

	-- Fallback: press the first day that is not marked as claimed.
	local menu = getMenu("DailyRewards")
	if not menu then
		return
	end

	for _, button in ipairs(menu:GetDescendants()) do
		if button:IsA("GuiButton") and button.Name:match("^Day%d$") then
			local claimed = button:FindFirstChild("Claimed")
			if not (claimed and claimed.Visible) and pressButton(button) then
				State.dailySent = State.dailySent + 1
				return
			end
		end
	end
end

local function startQuest()
	if State.questThread then
		return
	end

	State.autoQuest = true
	State.questThread = task.spawn(function()
		while State.autoQuest and AxionHub.alive do
			pcall(claimQuests)
			task.wait(State.claimInterval)
		end
	end)
end

local function stopQuest()
	State.autoQuest = false

	if State.questThread then
		pcall(task.cancel, State.questThread)
		State.questThread = nil
	end
end

local function startDaily()
	if State.dailyThread then
		return
	end

	State.autoDaily = true
	State.dailyThread = task.spawn(function()
		while State.autoDaily and AxionHub.alive do
			pcall(claimDaily)
			task.wait(State.claimInterval + 10)
		end
	end)
end

local function stopDaily()
	State.autoDaily = false

	if State.dailyThread then
		pcall(task.cancel, State.dailyThread)
		State.dailyThread = nil
	end
end

-- AFK 24/7.

---Apply or restore the fps cap used while AFK.
---@param enabled boolean
local function applyLowFps(enabled)
	State.lowFps = enabled

	if type(setfpscap) ~= "function" then
		return
	end

	pcall(setfpscap, enabled and 15 or State.defaultFps)
end

---Rejoin the game until the teleport goes through.
local function rejoin()
	if State.rejoining then
		return
	end

	State.rejoining = true
	State.reconnectStatus = "REJOINING"

	-- Reload the script after the teleport when it is saved in the workspace.
	if type(queue_on_teleport) == "function" and type(isfile) == "function" and isfile(AUTOLOAD_PATH) then
		pcall(queue_on_teleport, string.format("loadfile(%q)()", AUTOLOAD_PATH))
	end

	task.spawn(function()
		while AxionHub.alive and State.autoReconnect do
			pcall(function()
				if #playersService:GetPlayers() <= 1 then
					teleportService:Teleport(game.PlaceId, localPlayer)
				else
					teleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, localPlayer)
				end
			end)

			task.wait(15)
		end

		State.rejoining = false
		State.reconnectStatus = "STANDBY"
	end)
end

---Hook idle kicks, disconnect prompts and error messages.
local function initAfk()
	pcall(function()
		for _, connection in ipairs(getconnections(localPlayer.Idled)) do
			connection:Disable()
		end
	end)

	-- Fake input whenever roblox thinks we are idle.
	track(localPlayer.Idled:Connect(function()
		if not State.antiAfk then
			return
		end

		pcall(function()
			virtualUser:CaptureController()
			virtualUser:ClickButton2(Vector2.new())
		end)
	end))

	-- Insurance tick in case the idle event never fires.
	task.spawn(function()
		while AxionHub.alive do
			task.wait(240)

			if State.antiAfk then
				pcall(function()
					virtualUser:CaptureController()
					virtualUser:ClickButton2(Vector2.new())
				end)
			end
		end
	end)

	track(guiService.ErrorMessageChanged:Connect(function()
		if State.autoReconnect and guiService:GetErrorMessage() ~= "" then
			task.wait(2)
			rejoin()
		end
	end))

	task.spawn(function()
		local ok, overlay = pcall(function()
			return coreGui:WaitForChild("RobloxPromptGui", 10):WaitForChild("promptOverlay", 10)
		end)

		if not ok or not overlay then
			return
		end

		track(overlay.ChildAdded:Connect(function(child)
			if child.Name == "ErrorPrompt" and State.autoReconnect then
				task.wait(1.5)
				rejoin()
			end
		end))
	end)
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

local function createGradient(parent, rotation, colorSequence)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation or 90
	gradient.Color = colorSequence
	gradient.Parent = parent
	return gradient
end

-- Shared brand gradient (blue-violet to magenta-purple).
local function accentSequence()
	return ColorSequence.new(Config.accentBlue, Config.accentPink)
end

-- Gradient outline so frames glow like the logo.
local function createStroke(parent, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = WHITE
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	createGradient(stroke, 45, accentSequence())
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

-- Card: purple to black gradient with a faint glowing outline.
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

-- Capsule: dark base, gradient glow fades in when active, label stays untinted.
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

-- Pill toggle: gradient capsule fill fades in, knob slides.
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
	tween(parts.knob, 0.22, knobGoal)
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
		apply = function(value)
			on = value
			stylePill(parts, on)
			if callback then
				callback(on)
			end
		end,
	}
end

---Build a draggable slider (integer values) and return its setter.
---@param parent Instance
---@param position UDim2
---@param minValue number
---@param maxValue number
---@param initial number
---@param onChange function
---@param onRelease function
---@return function
local function makeSlider(parent, position, minValue, maxValue, initial, onChange, onRelease)
	local sliderTrack = Instance.new("TextButton")
	sliderTrack.Size = UDim2.new(1, -28, 0, 10)
	sliderTrack.Position = position
	sliderTrack.BackgroundColor3 = Config.track
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
	createGradient(fill, 0, accentSequence())

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.BackgroundColor3 = WHITE
	knob.BorderSizePixel = 0
	knob.ZIndex = 6
	knob.Parent = sliderTrack
	createCorner(knob, 999)
	createStroke(knob, 2, 0)

	local dragging = false

	local function setValue(value, silent)
		value = math.clamp(math.floor(value + 0.5), minValue, maxValue)

		local relative = (value - minValue) / (maxValue - minValue)
		fill.Size = UDim2.new(relative, 0, 1, 0)
		knob.Position = UDim2.new(relative, -8, 0.5, -8)

		if not silent then
			onChange(value)
		end
	end

	local function setFromX(x)
		local relative = math.clamp((x - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X, 0, 1)
		setValue(minValue + relative * (maxValue - minValue))
	end

	track(sliderTrack.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end))

	track(userInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
		then
			setFromX(input.Position.X)
		end
	end))

	track(userInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging and onRelease then
				onRelease()
			end

			dragging = false
		end
	end))

	setValue(initial, true)
	return setValue
end

---Build a group of capsule chips laid out in a grid.
---@param parent Instance
---@param options table
---@param layout table
---@param isActive function
---@param onSelect function
local function makeChipGroup(parent, options, layout, isActive, onSelect)
	local chips = {}
	local group = {}

	function group.refresh(instant)
		for key, chip in pairs(chips) do
			styleChip(chip, isActive(key), instant)
		end
	end

	for index, option in ipairs(options) do
		local column = (index - 1) % layout.columns
		local row = math.floor((index - 1) / layout.columns)

		local chip = makeChip(
			parent,
			UDim2.new(0, layout.width, 0, layout.height),
			UDim2.new(0, layout.x + column * (layout.width + layout.gap), 0, layout.y + row * (layout.height + layout.gap)),
			option.text,
			layout.textSize,
			999
		)
		chips[option.key] = chip
		addHover(chip)

		track(chip.button.MouseButton1Click:Connect(function()
			onSelect(option.key)
			group.refresh()
		end))
	end

	group.refresh(true)
	return group
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
	miniBtn.BackgroundColor3 = WHITE
	miniBtn.BorderSizePixel = 0
	miniBtn.Text = ""
	miniBtn.AutoButtonColor = false
	miniBtn.Visible = false
	miniBtn.Active = true
	miniBtn.Draggable = true
	miniBtn.Parent = gui
	createCorner(miniBtn, 999)
	createGradient(miniBtn, 45, accentSequence())
	createStroke(miniBtn, 1.5, 0.3)

	makeLabel(miniBtn, "◆", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Config.fontBold, 22, Config.text, Enum.TextXAlignment.Center)

	-- One window holds the sidebar and content side by side.
	local win = Instance.new("Frame")
	win.Name = "Window"
	win.Size = UDim2.new(0, 590, 0, 392)
	win.Position = UDim2.new(0.5, -295, 0.5, -196)
	win.BackgroundColor3 = WHITE
	win.BackgroundTransparency = 0.04
	win.BorderSizePixel = 0
	win.Active = true
	win.Parent = gui
	createCorner(win, CORNER_RADIUS + 4)
	createGradient(win, 115, ColorSequence.new(Config.bgTop, Config.bgBot))
	createStroke(win, 1.5, 0.15)

	-- Sidebar: deeper black so the content panel stands out.
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
	logoBox.Size = UDim2.new(0, 40, 0, 40)
	logoBox.Position = UDim2.new(0, 16, 0, 14)
	logoBox.BackgroundColor3 = WHITE
	logoBox.BorderSizePixel = 0
	logoBox.ZIndex = 3
	logoBox.Parent = sidebar
	createCorner(logoBox, CORNER_RADIUS)
	createGradient(logoBox, 45, accentSequence())
	createStroke(logoBox, 1, 0.4)

	makeLabel(logoBox, "◆", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Config.fontBold, 20, Config.text, Enum.TextXAlignment.Center)

	makeLabel(sidebar, "AxionHub", UDim2.new(1, -20, 0, 18), UDim2.new(0, 16, 0, 60), Config.fontBold, 15, Config.text)

	makeLabel(sidebar, "AutoDice  " .. HUB_VERSION, UDim2.new(1, -20, 0, 14), UDim2.new(0, 16, 0, 78), Config.font, 10, Config.accentLight)

	local pages = {
		{ id = "MAIN", icon = "🏠", label = "Main", desc = "dice & collect" },
		{ id = "DUNGEON", icon = "🗡", label = "Dungeon", desc = "auto tower" },
		{ id = "CLAIM", icon = "🎁", label = "Claim", desc = "quest & daily" },
		{ id = "AFK", icon = "🛡", label = "AFK 24/7", desc = "anti-afk / rejoin" },
		{ id = "SETTINGS", icon = "⚙", label = "Settings", desc = "animation / range" },
	}

	local pageButtons = {}

	for index, page in ipairs(pages) do
		local chip = makeChip(
			sidebar,
			UDim2.new(1, -24, 0, 40),
			UDim2.new(0, 12, 0, 108 + (index - 1) * 46),
			"",
			11,
			20
		)
		addHover(chip)

		local badge = Instance.new("Frame")
		badge.Size = UDim2.new(0, 26, 0, 26)
		badge.Position = UDim2.new(0, 8, 0.5, -13)
		badge.BackgroundColor3 = Config.bgBot
		badge.BackgroundTransparency = 0.35
		badge.BorderSizePixel = 0
		badge.ZIndex = 6
		badge.Parent = chip.button
		createCorner(badge, 999)

		local icon = makeLabel(badge, page.icon, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Config.fontBold, 13, Config.accentLight, Enum.TextXAlignment.Center)
		icon.ZIndex = 7

		local nameLabel = makeLabel(chip.button, page.label, UDim2.new(1, -46, 0, 14), UDim2.new(0, 42, 0, 5), Config.fontBold, 11, Config.textDim)
		nameLabel.ZIndex = 6
		local descLabel = makeLabel(chip.button, page.desc, UDim2.new(1, -46, 0, 12), UDim2.new(0, 42, 0, 21), Config.font, 8.5, Config.muted)
		descLabel.ZIndex = 6

		pageButtons[page.id] = {
			button = chip.button,
			chip = chip,
			name = nameLabel,
			desc = descLabel,
		}
	end

	-- Content panel (transparent, window gradient shows through).
	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, 0)
	content.Position = UDim2.new(0, SIDEBAR_WIDTH, 0, 0)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Parent = win

	local pageFrames = {}
	local headers = {}

	---Create a page with a header card on top.
	---@param id string
	---@param title string
	---@return Frame, TextLabel
	local function makePage(id, title)
		local page = Instance.new("Frame")
		page.Size = UDim2.new(1, 0, 1, 0)
		page.BackgroundTransparency = 1
		page.Visible = false
		page.Parent = content
		pageFrames[id] = page

		-- Header leaves room on the right for the window buttons.
		local header = makeCard(page, UDim2.new(1, -90, 0, 42), UDim2.new(0, 18, 0, 16))
		table.insert(headers, header)

		local label = makeLabel(header, title, UDim2.new(1, -44, 1, 0), UDim2.new(0, 16, 0, 0), Config.font, 11, Config.text)
		label.TextTruncate = Enum.TextTruncate.AtEnd

		return page, label
	end

	-- Main page.
	local mainPage, mainStatus = makePage("MAIN", "READY")
	mainStatus.Position = UDim2.new(0, 30, 0, 0)

	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 8, 0, 8)
	dot.Position = UDim2.new(0, 14, 0.5, -4)
	dot.BackgroundColor3 = Config.muted
	dot.BorderSizePixel = 0
	dot.ZIndex = 5
	dot.Parent = mainStatus.Parent
	createCorner(dot, 999)

	-- Mode card.
	local modeCard = makeCard(mainPage, UDim2.new(1, -36, 0, 132), UDim2.new(0, 18, 0, 70))

	makeLabel(modeCard, "MODE", UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 8), Config.fontBold, 9.5, Config.accentLight)

	local modeDesc = makeLabel(modeCard, MODE_INFO[State.mode], UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 66), Config.font, 10, Config.muted)

	makeChipGroup(
		modeCard,
		{ { key = "AUTO", text = "AUTO" }, { key = "SPAM", text = "SPAM" }, { key = "BOTH", text = "BOTH" } },
		{ columns = 3, x = 14, y = 28, width = 82, height = 30, gap = 8, textSize = 11 },
		function(key)
			return key == State.mode
		end,
		function(key)
			State.mode = key
			modeDesc.Text = MODE_INFO[key]
			saveConfig()
		end
	)

	-- Same toggle builder everywhere so every switch matches.
	Toggles.roll = makeToggle(modeCard, 88, "🎲 Auto Roll", false, function(value)
		if value then
			startDice()
		else
			stopDice()
		end

		Toggles.roll.set(State.running)
		saveConfig()
	end)

	-- Speed card.
	local speedCard = makeCard(mainPage, UDim2.new(1, -36, 0, 62), UDim2.new(0, 18, 0, 212))

	makeLabel(speedCard, "SPAM SPEED", UDim2.new(0.5, 0, 0, 14), UDim2.new(0, 14, 0, 8), Config.fontBold, 9.5, Config.accentLight)

	local speedValue = makeLabel(speedCard, "33 / sec", UDim2.new(0.5, -14, 0, 14), UDim2.new(0.5, 0, 0, 8), Config.fontBold, 11, Config.text, Enum.TextXAlignment.Right)

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

	local function applyRelative(relative)
		fill.Size = UDim2.new(relative, 0, 1, 0)
		sliderKnob.Position = UDim2.new(relative, -8, 0.5, -8)

		local rate = math.floor(20 + relative * 180)
		State.spamSpeed = 1 / rate
		speedValue.Text = rate .. " / sec"
	end

	local function setFromX(x)
		applyRelative(math.clamp((x - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X, 0, 1))
	end

	-- Match the slider to the current spam speed.
	local initialRate = math.clamp(math.floor(1 / State.spamSpeed + 0.5), 20, 200)
	fill.Size = UDim2.new((initialRate - 20) / 180, 0, 1, 0)
	sliderKnob.Position = UDim2.new((initialRate - 20) / 180, -8, 0.5, -8)
	speedValue.Text = initialRate .. " / sec"

	track(sliderTrack.InputBegan:Connect(function(input)
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
			if draggingSlider then
				saveConfig()
			end

			draggingSlider = false
		end
	end))

	-- Collect card.
	local collectCard = makeCard(mainPage, UDim2.new(1, -36, 0, 62), UDim2.new(0, 18, 0, 284))

	Toggles.collect = makeToggle(collectCard, 4, "💰 AFK Collect Money", false, function(value)
		if value then
			startCollect()
		else
			stopCollect()
		end

		Toggles.collect.set(State.autoCollect)
		saveConfig()
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

	-- Dungeon page.
	local dungeonPage, dungeonStatus = makePage("DUNGEON", "🗡 OFF")

	local towerCard = makeCard(dungeonPage, UDim2.new(1, -36, 0, 132), UDim2.new(0, 18, 0, 70))

	makeLabel(towerCard, "SELECT DUNGEON", UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 8), Config.fontBold, 9.5, Config.accentLight)

	local towerOptions = {}
	for _, name in ipairs(TOWERS) do
		table.insert(towerOptions, { key = name, text = name })
	end

	makeChipGroup(
		towerCard,
		towerOptions,
		{ columns = 3, x = 14, y = 28, width = 122, height = 28, gap = 6, textSize = 9.5 },
		function(key)
			return key == State.tower
		end,
		function(key)
			State.tower = key
			saveConfig()
		end
	)

	local towerToggles = makeCard(dungeonPage, UDim2.new(1, -36, 0, 92), UDim2.new(0, 18, 0, 210))

	makeToggle(towerToggles, 4, "🧬 Best Team", State.towerBest, function(value)
		State.towerBest = value
		saveConfig()
	end)

	Toggles.autoTower = makeToggle(towerToggles, 48, "🗡 Auto Dungeon", false, function(value)
		if value then
			startTower()
		else
			stopTower()
		end

		Toggles.autoTower.set(State.autoTower)
		saveConfig()
	end)

	makeLabel(dungeonPage, "ยืนอยู่ที่ base ได้เลย ระบบจัดทีมและเข้าด่านให้เอง", UDim2.new(1, -36, 0, 14), UDim2.new(0, 22, 0, 310), Config.font, 10, Config.muted)

	-- Claim page.
	local claimPage, claimStatus = makePage("CLAIM", "🎁 quest: 0 · daily: 0")

	local claimCard = makeCard(claimPage, UDim2.new(1, -36, 0, 92), UDim2.new(0, 18, 0, 70))

	Toggles.quest = makeToggle(claimCard, 4, "📜 Auto Claim Quest", false, function(value)
		if value then
			startQuest()
		else
			stopQuest()
		end

		saveConfig()
	end)

	Toggles.daily = makeToggle(claimCard, 48, "🎁 Auto Daily Reward", false, function(value)
		if value then
			startDaily()
		else
			stopDaily()
		end

		saveConfig()
	end)

	makeLabel(claimPage, "เช็กและกดรับของให้อัตโนมัติทุก 20 วินาที", UDim2.new(1, -36, 0, 14), UDim2.new(0, 22, 0, 172), Config.font, 10, Config.muted)

	-- AFK page.
	local afkPage, afkStatus = makePage("AFK", "🛡 anti-afk: on · reconnect: standby")

	local afkCard = makeCard(afkPage, UDim2.new(1, -36, 0, 136), UDim2.new(0, 18, 0, 70))

	Toggles.antiAfk = makeToggle(afkCard, 4, "🛡 Anti-AFK", State.antiAfk, function(value)
		State.antiAfk = value
		saveConfig()
	end)

	Toggles.autoReconnect = makeToggle(afkCard, 48, "🔄 Auto Reconnect", State.autoReconnect, function(value)
		State.autoReconnect = value
		saveConfig()
	end)

	Toggles.lowFps = makeToggle(afkCard, 92, "💤 Low Power (15 FPS)", false, function(value)
		applyLowFps(value)
		saveConfig()
	end)

	-- One tap preset that turns every farming and AFK system on.
	local presetChip = makeChip(afkPage, UDim2.new(1, -36, 0, 36), UDim2.new(0, 18, 0, 216), "⚡  START AFK 24/7", 12, 999)
	styleChip(presetChip, true, true)

	track(presetChip.button.MouseButton1Click:Connect(function()
		for _, key in ipairs({ "roll", "collect", "autoTower", "quest", "daily", "antiAfk", "autoReconnect" }) do
			Toggles[key].apply(true)
		end
	end))

	makeLabel(afkPage, "เปิดฟาร์มทุกระบบ + กันหลุด + รีจอยน์อัตโนมัติ", UDim2.new(1, -36, 0, 14), UDim2.new(0, 22, 0, 260), Config.font, 10, Config.muted)

	makeLabel(afkPage, "รีโหลดสคริปต์หลังรีจอยน์: วางไฟล์ที่ workspace/AxionHub/AutoDice.lua", UDim2.new(1, -36, 0, 14), UDim2.new(0, 22, 0, 278), Config.font, 9, Config.muted)

	-- Settings page.
	local settingsPage = makePage("SETTINGS", "⚙  Settings")

	local settingsCard = makeCard(settingsPage, UDim2.new(1, -36, 0, 92), UDim2.new(0, 18, 0, 70))

	makeToggle(settingsCard, 4, "Bypass Roll Animation", State.bypassAnim, function(value)
		State.bypassAnim = value
		saveConfig()
	end)

	makeToggle(settingsCard, 48, "Kill Camera Cutscene", State.killCutscene, function(value)
		State.killCutscene = value
		saveConfig()
	end)

	local rangeCard = makeCard(settingsPage, UDim2.new(1, -36, 0, 80), UDim2.new(0, 18, 0, 172))

	makeLabel(rangeCard, "PLOT RANGE", UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 8), Config.fontBold, 9.5, Config.accentLight)

	local rangeValue = makeLabel(rangeCard, string.format("1 → %d", State.plotMax), UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 26), Config.font, 10, Config.text)

	makeChipGroup(
		rangeCard,
		{ { key = 4, text = "1 → 4" }, { key = 8, text = "1 → 8" }, { key = 16, text = "1 → 16" } },
		{ columns = 3, x = 14, y = 46, width = 56, height = 26, gap = 6, textSize = 10 },
		function(key)
			return key == State.plotMax
		end,
		function(key)
			State.plotMin = 1
			State.plotMax = key
			rangeValue.Text = string.format("1 → %d", key)
			saveConfig()
		end
	)

	local floorCard = makeCard(settingsPage, UDim2.new(1, -36, 0, 82), UDim2.new(0, 18, 0, 262))

	makeLabel(floorCard, "DUNGEON FLOORS / RUN", UDim2.new(0.6, 0, 0, 14), UDim2.new(0, 14, 0, 8), Config.fontBold, 9.5, Config.accentLight)

	local floorValue = makeLabel(floorCard, "", UDim2.new(0.4, -14, 0, 14), UDim2.new(0.6, 0, 0, 8), Config.fontBold, 11, Config.text, Enum.TextXAlignment.Right)

	local floorChips

	local setFloors = makeSlider(
		floorCard,
		UDim2.new(0, 14, 0, 32),
		1,
		MAX_FLOORS,
		State.towerFloors,
		function(value)
			State.towerFloors = value
			floorValue.Text = value .. " floors"
			floorChips.refresh()
		end,
		saveConfig
	)
	floorValue.Text = State.towerFloors .. " floors"

	floorChips = makeChipGroup(
		floorCard,
		{ { key = 10, text = "10" }, { key = 50, text = "50" }, { key = 100, text = "100" } },
		{ columns = 3, x = 14, y = 50, width = 56, height = 24, gap = 6, textSize = 10 },
		function(key)
			return key == State.towerFloors
		end,
		function(key)
			setFloors(key)
			saveConfig()
		end
	)

	-- Page switching.
	local function applyPage(instant)
		for id, data in pairs(pageButtons) do
			local on = id == State.page
			data.name.TextColor3 = on and Config.text or Config.textDim
			data.desc.TextColor3 = on and Config.text or Config.muted
			styleChip(data.chip, on, instant)
		end

		for id, frame in pairs(pageFrames) do
			frame.Visible = id == State.page
		end
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

	local minChip = makeChip(topButtons, UDim2.new(0, 22, 0, 22), UDim2.new(0, 0, 0, 0), "—", 13, 999)
	minChip.button.ZIndex = 11
	styleChip(minChip, false, true)
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

	track(closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(190, 48, 92) })
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

	track(minChip.button.MouseButton1Click:Connect(function()
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

	for _, handle in ipairs(headers) do
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

	-- Live status for every page header.
	task.spawn(function()
		while mainStatus.Parent and AxionHub.alive do
			local status = remotesReady and (State.running and "RUNNING" or "IDLE") or "NO REMOTES"
			local color = remotesReady and (State.running and Config.good or Config.muted) or Config.bad

			mainStatus.Text = string.format("💤 · %s · rolls: %d · 💰 %d", status, State.rolls, State.collected)
			dot.BackgroundColor3 = color

			dungeonStatus.Text = string.format(
				"🗡 %s · runs: %d · floors: %d",
				towerReady and State.towerStatus or "NO REMOTES",
				State.towerRuns,
				State.towerFloorsDone
			)
			claimStatus.Text = string.format("🎁 quest: %d · daily: %d", State.questSent, State.dailySent)
			afkStatus.Text = string.format(
				"🛡 anti-afk: %s · reconnect: %s",
				State.antiAfk and "on" or "off",
				State.autoReconnect and State.reconnectStatus:lower() or "off"
			)

			task.wait(0.25)
		end
	end)

	applyPage(true)
	return gui
end

---Stop everything and remove the interface.
function AxionHub.detach()
	AxionHub.alive = false

	pcall(stopDice)
	pcall(stopCollect)
	pcall(stopTower)
	pcall(stopQuest)
	pcall(stopDaily)
	pcall(applyLowFps, false)

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
	local saved = loadConfig()

	if saved.antiAfk ~= nil then
		State.antiAfk = saved.antiAfk == true
	end
	if saved.autoReconnect ~= nil then
		State.autoReconnect = saved.autoReconnect == true
	end

	if type(getfpscap) == "function" then
		local fps = tonumber(getfpscap())
		State.defaultFps = (fps and fps > 0) and fps or 240
	end

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
	initAfk()

	-- Resume every system that was running before the last session ended.
	for savedKey, toggleKey in pairs({
		roll = "roll",
		collect = "collect",
		autoTower = "autoTower",
		quest = "quest",
		daily = "daily",
		lowFps = "lowFps",
	}) do
		if saved[savedKey] == true then
			Toggles[toggleKey].apply(true)
		end
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
