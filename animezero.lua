-- Anime Zero Kaitun v2 (lobby only), UI layer = AxionLib (loaded from URL, content injected into its Main page).
-- Systems: Account Monitor, Auto Claim (milestones / daily / quests), Delivery Monitor, Queue Monitor, Activity Log.
-- Evidence: anime_zerokaitun_lua.txt (old script call sites). Not tested in-game.

-- Check for table that is shared between executions.
if not shared then
	return warn("No shared, no script.")
end

-- Services.
local cloneRef = cloneref or function(value)
	return value
end

local playersService = cloneRef(game:GetService("Players"))
local replicatedStorage = cloneRef(game:GetService("ReplicatedStorage"))
local tweenService = cloneRef(game:GetService("TweenService"))

-- Constants.
local CONFIG = {
	waitTimeout = 20,
	claimInterval = 2,
	pendingCooldown = 6,
	verifyDelay = 2,
	snapshotTtl = 0.75,
	uiRefresh = 1,
	maxFailures = 5,
	maxLogEntries = 100,
	shownLogEntries = 8,
	axionLibUrl = "https://raw.githubusercontent.com/alwayszoey/script-openv1/refs/heads/main/Lib/AxionLib.lua",
}

local STATUS = {
	confirmed = "CONFIRMED",
	partial = "PARTIAL",
	unverified = "UNVERIFIED",
}

-- State.
local localPlayer = playersService.LocalPlayer

local Kaitun = {
	alive = true,
	generation = 0,
	handles = {},
	connections = {},
	container = nil,
	placeholder = nil,
	headerLabel = nil,
	hub = nil,
}

local State = {
	inLobby = replicatedStorage:FindFirstChild("lobby") ~= nil,
	modules = {},
	moduleErrors = {},
	flags = { milestones = false, daily = false, quests = false },
	counters = { milestones = 0, daily = 0, quests = 0, verified = 0, unverified = 0 },
	failures = 0,
	requestId = 0,
	pending = {},
	delivery = nil,
	deliveryAt = nil,
	queueStatus = nil,
	queueRoom = nil,
	queueAt = nil,
	snapshot = nil,
	snapshotAt = 0,
	snapshotError = nil,
	startedAt = os.clock(),
	log = {},
}

---Append a real event to the activity log.
---@param system string
---@param action string
---@param result string
---@param detail string?
local function logEvent(system, action, result, detail)
	table.insert(State.log, {
		time = os.date("%H:%M:%S"),
		system = system,
		action = action,
		result = result,
		detail = detail,
	})

	while #State.log > CONFIG.maxLogEntries do
		table.remove(State.log, 1)
	end
end

---Store a connection or handle so it can be released on unload.
---@param handle any
local function track(handle)
	table.insert(Kaitun.handles, handle)
	return handle
end

---Release a handle returned by event:on or an RBXScriptConnection.
---@param handle any
local function release(handle)
	local kind = typeof(handle)

	if kind == "function" then
		pcall(handle)
	elseif kind == "RBXScriptConnection" then
		handle:Disconnect()
	elseif kind == "table" and type(handle.Disconnect) == "function" then
		pcall(handle.Disconnect, handle)
	end
end

-- Game data adapter.

---Wait for an instance path without erroring.
---@param root Instance
---@return Instance?
local function waitPath(root, ...)
	local node = root

	for _, name in ipairs({ ... }) do
		if not node then
			return nil
		end

		node = node:WaitForChild(name, CONFIG.waitTimeout)
	end

	return node
end

---Require a game module with a lowered thread identity so our environment is not exposed.
---@return any?, string?
local function safeRequire(root, ...)
	local path = table.concat({ ... }, ".")
	local instance = waitPath(root, ...)
	if not instance then
		return nil, "missing: " .. path
	end

	local previousIdentity
	if getthreadidentity and setthreadidentity then
		previousIdentity = getthreadidentity()
		pcall(setthreadidentity, 2)
	end

	local ok, result = pcall(require, instance)

	if previousIdentity then
		pcall(setthreadidentity, previousIdentity)
	end

	if not ok then
		return nil, "require failed: " .. path .. " (" .. tostring(result) .. ")"
	end

	return result
end

---Load the lobby modules that the claim and monitor systems depend on.
local function loadModules()
	if not State.inLobby then
		State.moduleErrors.lobby = "not in lobby place"
		return
	end

	local targets = {
		{ "LobbyPackets", replicatedStorage, "lobby", "packets" },
		{ "Account", replicatedStorage, "global", "stores", "accountNamespace" },
		{ "Levels", replicatedStorage, "global", "utils", "levelProgression" },
		{ "MilestoneConfig", replicatedStorage, "assets", "config", "levelMilestoneConfig" },
		{ "QuestConfig", replicatedStorage, "assets", "config", "questConfig" },
	}

	for _, target in ipairs(targets) do
		local name = table.remove(target, 1)
		local module, reason = safeRequire(table.unpack(target))

		if module then
			State.modules[name] = module
		else
			State.moduleErrors[name] = reason
			logEvent("DATA", "load " .. name, "Failed", reason)
		end
	end
end

---Next request id (1..65535), same scheme as the reference script.
---@return number
local function nextRequestId()
	State.requestId = State.requestId % 65535 + 1
	return State.requestId
end

---Read the local account as a plain table (cached briefly).
---@return table?
local function accountSnapshot(force)
	local clock = os.clock()
	if not force and State.snapshot and clock - State.snapshotAt < CONFIG.snapshotTtl then
		return State.snapshot
	end

	local Account = State.modules.Account
	if not Account then
		State.snapshotError = State.moduleErrors.Account or "Account module not loaded"
		return nil
	end

	local okStore, store = pcall(Account.getLocalPlayerAccount)
	if not okStore or not store then
		State.snapshotError = "WAITING_FOR_DATA: account store unavailable"
		return nil
	end

	local okTable, snapshot = pcall(store.toTable, store)
	if not okTable or type(snapshot) ~= "table" then
		State.snapshotError = "WAITING_FOR_DATA: toTable failed"
		return nil
	end

	State.snapshot = snapshot
	State.snapshotAt = clock
	State.snapshotError = nil
	return snapshot
end

---Compute the player level from xp.
---@return number?
local function playerLevel(snapshot)
	local Levels = State.modules.Levels
	if not Levels or not snapshot.currencies then
		return nil
	end

	local ok, progress = pcall(Levels.getProgress, tonumber(snapshot.currencies.xp) or 0)
	if ok and type(progress) == "table" then
		return tonumber(progress.level)
	end

	return nil
end

---Rate limit a request key.
---@return boolean
local function notPending(key)
	local clock = os.clock()
	local sent = State.pending[key]
	if sent and clock - sent < CONFIG.pendingCooldown then
		return false
	end

	State.pending[key] = clock
	return true
end

---Re-read the account later and record whether the claim really changed state.
---@param key string
---@param check function
local function verifyLater(system, key, check)
	task.delay(CONFIG.verifyDelay, function()
		if not Kaitun.alive then
			return
		end

		local snapshot = accountSnapshot(true)
		local ok, claimed = pcall(check, snapshot)

		if ok and claimed then
			State.counters.verified += 1
			logEvent(system, "claim " .. key, "Success", "verified in account data")
		else
			State.counters.unverified += 1
			logEvent(system, "claim " .. key, "Skipped", "no state change seen after request")
		end
	end)
end

-- Event listeners (Delivery / Queue monitors).

---Listen to a lobby packet event, handling any handle shape.
local function listen(event, handler, label)
	if not event then
		logEvent("DATA", "listen " .. label, "Failed", "packet missing")
		return
	end

	local ok, handle = pcall(function()
		return event:on(handler)
	end)

	if not ok then
		logEvent("DATA", "listen " .. label, "Failed", tostring(handle))
		return
	end

	track(handle)
end

---Connect packet listeners once.
local function connectListeners()
	local packets = State.modules.LobbyPackets
	if not packets then
		return
	end

	listen(packets.deliveryState, function(state)
		if type(state) ~= "table" then
			return
		end

		local changed = not State.delivery or State.delivery.status ~= state.status
		State.delivery = state
		State.deliveryAt = os.clock()

		if changed then
			logEvent("DELIVERY", "state", "Success", tostring(state.status))
		end
	end, "deliveryState")

	listen(packets.updateClientQuqueStatus, function(status)
		if State.queueStatus ~= status then
			logEvent("QUEUE", "status", "Success", tostring(status))
		end

		State.queueStatus = status
		State.queueAt = os.clock()
	end, "updateClientQuqueStatus")

	listen(packets.toggleQuqueWindow, function(data)
		if type(data) ~= "table" then
			return
		end

		State.queueRoom = data.open and data.roomNumber or nil
		State.queueAt = os.clock()
	end, "toggleQuqueWindow")
end

-- Auto claim controller.

---Claim level milestones whose level is reached and not yet claimed.
local function stepMilestones(snapshot)
	local packets, config = State.modules.LobbyPackets, State.modules.MilestoneConfig
	local level = playerLevel(snapshot)
	local claimedMap = snapshot.claimedLevelMilestones

	if not (packets and config and level and type(claimedMap) == "table") then
		return
	end

	for key in pairs(config.milestones or {}) do
		local milestone = tonumber(key)

		if milestone and milestone <= level and claimedMap[tostring(milestone)] ~= true and notPending("milestone" .. milestone) then
			packets.claimLevelMilestone:fire({ level = milestone, requestId = nextRequestId() })
			State.counters.milestones += 1
			logEvent("MILESTONE", "claim " .. milestone, "Sent")

			verifyLater("MILESTONE", tostring(milestone), function(fresh)
				return fresh.claimedLevelMilestones[tostring(milestone)] == true
			end)

			task.wait(0.35)
		end
	end
end

---Claim daily reward days reported as "available".
local function stepDaily(snapshot)
	local packets = State.modules.LobbyPackets
	local rewards = snapshot.dailyReward and snapshot.dailyReward.rewards

	if not (packets and type(rewards) == "table") then
		return
	end

	for day = 1, 7 do
		local state = rewards[day] or rewards[tostring(day)]

		if state == "available" and notPending("daily" .. day) then
			packets.claimDailyReward:fire(day)
			State.counters.daily += 1
			logEvent("DAILY", "claim day " .. day, "Sent")

			verifyLater("DAILY", "day " .. day, function(fresh)
				local now = fresh.dailyReward.rewards
				return (now[day] or now[tostring(day)]) ~= "available"
			end)

			task.wait(0.5)
		end
	end
end

---Claim quests that are completed and not claimed.
local function stepQuests(snapshot)
	local packets, config = State.modules.LobbyPackets, State.modules.QuestConfig
	local quests = snapshot.quests

	if not (packets and config and type(quests) == "table" and quests.completed and quests.claimed) then
		return
	end

	for id in pairs(config.quests or {}) do
		if quests.completed[id] == true and quests.claimed[id] ~= true and notPending("quest" .. tostring(id)) then
			packets.claimQuestReward:fire({ questId = id, requestId = nextRequestId() })
			State.counters.quests += 1
			logEvent("QUEST", "claim " .. tostring(id), "Sent")

			verifyLater("QUEST", tostring(id), function(fresh)
				return fresh.quests.claimed[id] == true
			end)

			task.wait(0.4)
		end
	end
end

---One scheduler pass over every enabled claim system.
local function claimStep()
	local flags = State.flags
	if not (flags.milestones or flags.daily or flags.quests) then
		return
	end

	local snapshot = accountSnapshot(true)
	if not snapshot then
		return
	end

	if flags.milestones then
		stepMilestones(snapshot)
	end

	if flags.daily then
		stepDaily(snapshot)
	end

	if flags.quests then
		stepQuests(snapshot)
	end
end

---Start the single claim worker (a new generation cancels the old one).
local function startClaimWorker()
	Kaitun.generation += 1
	local generation = Kaitun.generation

	task.spawn(function()
		while Kaitun.alive and Kaitun.generation == generation do
			local ok, err = pcall(claimStep)

			if ok then
				State.failures = 0
			else
				State.failures += 1
				logEvent("CLAIM", "step", "Failed", tostring(err))

				-- Stop only the claim systems after repeated errors.
				if State.failures >= CONFIG.maxFailures then
					State.flags.milestones, State.flags.daily, State.flags.quests = false, false, false
					logEvent("CLAIM", "auto-stop", "Failed", "too many consecutive errors")
					State.failures = 0
				end
			end

			task.wait(CONFIG.claimInterval)
		end
	end)
end

-- Dashboard.

---Format seconds as HH:MM:SS.
local function formatTime(seconds)
	seconds = math.floor(seconds)
	return string.format("%02d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
end

---Count entries in a table that satisfy a predicate.
local function countWhere(map, predicate)
	local total = 0

	for key, value in pairs(type(map) == "table" and map or {}) do
		if predicate(key, value) then
			total += 1
		end
	end

	return total
end

---Account section text from real account data.
---@return string
local function accountText()
	local lines = {}

	table.insert(lines, string.format("%s (%s)  id %d", localPlayer.Name, localPlayer.DisplayName, localPlayer.UserId))
	table.insert(lines, "Session " .. formatTime(os.clock() - State.startedAt))

	if not State.inLobby then
		table.insert(lines, "UNAVAILABLE: not in lobby place")
		return table.concat(lines, "\n")
	end

	local snapshot = accountSnapshot()
	if not snapshot then
		table.insert(lines, tostring(State.snapshotError or "WAITING_FOR_DATA"))
		return table.concat(lines, "\n")
	end

	local currencies = snapshot.currencies or {}
	table.insert(lines, string.format("Level %s   XP %s", tostring(playerLevel(snapshot) or "Unknown"), tostring(currencies.xp or "Unknown")))
	table.insert(lines, string.format("Money %s   Gems %s", tostring(currencies.money or "?"), tostring(currencies.gems or "?")))
	table.insert(lines, string.format("Lucky spins %s   Rolls %s", tostring(currencies.luckySpins or "?"), tostring(currencies.rolls or "?")))

	local unlocked = countWhere(snapshot.UnlockedCharacters, function(_, slot)
		return type(slot) == "table" and slot.Unlocked == true
	end)
	table.insert(lines, string.format("Character %s   Slots unlocked %d", tostring(snapshot.character or "Unknown"), unlocked))

	local quests = snapshot.quests or {}
	local claimable = countWhere(quests.completed, function(id, done)
		return done == true and not (quests.claimed and quests.claimed[id] == true)
	end)
	local claimedQuests = countWhere(quests.claimed, function(_, done)
		return done == true
	end)
	local dailyReady = countWhere(snapshot.dailyReward and snapshot.dailyReward.rewards, function(_, value)
		return value == "available"
	end)
	table.insert(lines, string.format("Quests claimable %d / claimed %d   Daily available %d", claimable, claimedQuests, dailyReady))

	return table.concat(lines, "\n")
end

---Claim counters text.
---@return string
local function claimText()
	return string.format(
		"Sent M%d D%d Q%d | verified %d | unchanged %d",
		State.counters.milestones,
		State.counters.daily,
		State.counters.quests,
		State.counters.verified,
		State.counters.unverified
	)
end

---Delivery and queue text from received events only.
---@return string
local function monitorText()
	local lines = {}
	local delivery = State.delivery

	if delivery then
		table.insert(lines, string.format(
			"Delivery %s | target %s | %s/%s | %s ago",
			tostring(delivery.status),
			tostring(delivery.target),
			tostring(delivery.dailyCount or "?"),
			tostring(delivery.dailyLimit or "?"),
			formatTime(os.clock() - State.deliveryAt)
		))
	else
		table.insert(lines, "Delivery WAITING_FOR_DATA (no deliveryState yet)")
	end

	table.insert(lines, string.format("Queue %s | room %s", tostring(State.queueStatus or "WAITING_FOR_DATA"), tostring(State.queueRoom or "-")))
	return table.concat(lines, "\n")
end

---Recent activity log text.
---@return string
local function logText()
	local lines = {}
	local first = math.max(1, #State.log - CONFIG.shownLogEntries + 1)

	for index = first, #State.log do
		local entry = State.log[index]
		table.insert(lines, string.format("[%s] %s %s: %s%s", entry.time, entry.system, entry.action, entry.result, entry.detail and (" - " .. entry.detail) or ""))
	end

	return #lines > 0 and table.concat(lines, "\n") or "No events yet."
end

-- AxionLib UI layer.

---Load AxionLib from its URL (it builds its own window, sidebar, icons, sounds and unload).
---@return table?, string?
local function loadAxionLib()
	local source
	local okGet, body = pcall(function()
		return game:HttpGet(CONFIG.axionLibUrl)
	end)

	if okGet and type(body) == "string" and #body > 0 then
		source = body
	elseif type(request) == "function" then
		local okRequest, response = pcall(request, { Url = CONFIG.axionLibUrl, Method = "GET" })
		if okRequest and response and response.Success then
			source = response.Body
		end
	end

	if not source then
		return nil, "AxionLib URL not reachable. Attach AxionLib.lua so it can be embedded."
	end

	local chunk, compileError = loadstring(source, "AxionLib")
	if not chunk then
		return nil, "AxionLib compile error: " .. tostring(compileError)
	end

	local okRun, runError = pcall(chunk)
	if not okRun then
		return nil, "AxionLib run error: " .. tostring(runError)
	end

	local hub = shared.AxionHub
	if not (hub and hub.alive and hub.gui) then
		return nil, "AxionLib did not expose shared.AxionHub.gui"
	end

	return hub
end

---Find AxionLib's empty Main page (the library marks it as the place for script content).
---@return Frame?, Frame?
local function findMainPage(hub)
	for _, descendant in ipairs(hub.gui:GetDescendants()) do
		if descendant:IsA("TextLabel") and string.find(descendant.Text, "This page is empty", 1, true) then
			local placeholder = descendant.Parent
			return placeholder and placeholder.Parent, placeholder
		end
	end

	return nil, nil
end

local PALETTE = {
	cardTop = Color3.fromRGB(44, 20, 82),
	cardBot = Color3.fromRGB(14, 6, 28),
	chipOff = Color3.fromRGB(26, 14, 44),
	track = Color3.fromRGB(10, 5, 20),
	text = Color3.fromRGB(255, 255, 255),
	muted = Color3.fromRGB(150, 132, 188),
	accent = Color3.fromRGB(172, 44, 248),
	accentLight = Color3.fromRGB(206, 164, 255),
}

---Create a label that matches the AxionLib look.
local function makeText(parent, size, position, textSize, color, font)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.GothamMedium
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.Text = ""
	label.Parent = parent
	return label
end

---Create a card that matches AxionLib cards.
local function makeInfoCard(parent, height, title, order)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, height)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 100
	gradient.Color = ColorSequence.new(PALETTE.cardTop, PALETTE.cardBot)
	gradient.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = PALETTE.accent
	stroke.Transparency = 0.6
	stroke.Parent = card

	makeText(card, UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 8), 9.5, PALETTE.accentLight, Enum.Font.GothamBold).Text = title
	return card
end

---Create a rounded button.
local function makeButton(parent, size, position, text, callback)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = PALETTE.chipOff
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 11
	button.TextColor3 = PALETTE.text
	button.Text = text
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	track(button.MouseButton1Click:Connect(callback))
	return button
end

---Create a toggle row. Returns a function that re-syncs the visual with the state.
local function makeToggleRow(parent, y, title, flag)
	makeText(parent, UDim2.new(0.6, 0, 0, 20), UDim2.new(0, 14, 0, y + 4), 12, PALETTE.text).Text = title

	local pill = makeButton(parent, UDim2.new(0, 46, 0, 24), UDim2.new(1, -60, 0, y + 2), "", function()
		if not State.modules.LobbyPackets then
			logEvent("CLAIM", title, "Skipped", "UNAVAILABLE: lobby packets not loaded")
			return
		end

		State.flags[flag] = not State.flags[flag]
		logEvent("CLAIM", title .. (State.flags[flag] and " enabled" or " disabled"), "Success")
	end)
	pill.AutoButtonColor = false

	local corner = pill:FindFirstChildOfClass("UICorner")
	corner.CornerRadius = UDim.new(0, 12)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 18, 0, 18)
	knob.BorderSizePixel = 0
	knob.Parent = pill

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(0, 9)
	knobCorner.Parent = knob

	return function()
		local on = State.flags[flag]
		pill.BackgroundColor3 = on and PALETTE.accent or PALETTE.track
		knob.BackgroundColor3 = on and PALETTE.text or PALETTE.muted
		tweenService:Create(knob, TweenInfo.new(0.15), { Position = on and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9) }):Play()
	end
end

---Create a numeric stepper bound to a CONFIG key.
---@return function
local function makeStepperRow(parent, y, title, key, minimum, maximum)
	makeText(parent, UDim2.new(0.5, 0, 0, 20), UDim2.new(0, 14, 0, y + 4), 12, PALETTE.text).Text = title

	local valueLabel = makeText(parent, UDim2.new(0, 40, 0, 20), UDim2.new(1, -96, 0, y + 4), 12, PALETTE.accentLight, Enum.Font.GothamBold)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Center

	makeButton(parent, UDim2.new(0, 24, 0, 24), UDim2.new(1, -124, 0, y + 2), "-", function()
		CONFIG[key] = math.max(minimum, CONFIG[key] - 1)
	end)

	makeButton(parent, UDim2.new(0, 24, 0, 24), UDim2.new(1, -52, 0, y + 2), "+", function()
		CONFIG[key] = math.min(maximum, CONFIG[key] + 1)
	end)

	return function()
		valueLabel.Text = tostring(CONFIG[key]) .. "s"
	end
end

---Inject Kaitun content into AxionLib's Main page.
local function injectUI(hub)
	local mainPage, placeholder = findMainPage(hub)
	if not mainPage then
		error("AxionLib Main page not found (library structure changed)", 0)
	end

	Kaitun.hub = hub
	Kaitun.placeholder = placeholder
	placeholder.Visible = false

	-- Reuse the library header label for the subtitle.
	for _, descendant in ipairs(mainPage:GetDescendants()) do
		if descendant:IsA("TextLabel") and descendant.Text == "READY" then
			Kaitun.headerLabel = descendant
			break
		end
	end

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "KaitunContent"
	scroll.Size = UDim2.new(1, -36, 1, -74)
	scroll.Position = UDim2.new(0, 18, 0, 66)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 3
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = mainPage
	Kaitun.container = scroll

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local accountCard = makeInfoCard(scroll, 126, "ACCOUNT MONITOR", 1)
	local accountLabel = makeText(accountCard, UDim2.new(1, -28, 1, -28), UDim2.new(0, 14, 0, 26), 11, PALETTE.text)

	local claimCard = makeInfoCard(scroll, 150, "AUTO CLAIM", 2)
	local syncMilestones = makeToggleRow(claimCard, 24, "Milestones", "milestones")
	local syncDaily = makeToggleRow(claimCard, 56, "Daily Rewards", "daily")
	local syncQuests = makeToggleRow(claimCard, 88, "Quest Rewards", "quests")
	local claimLabel = makeText(claimCard, UDim2.new(1, -28, 0, 16), UDim2.new(0, 14, 0, 124), 10, PALETTE.muted)

	local monitorCard = makeInfoCard(scroll, 70, "DELIVERY & QUEUE", 3)
	local monitorLabel = makeText(monitorCard, UDim2.new(1, -28, 1, -28), UDim2.new(0, 14, 0, 26), 11, PALETTE.text)

	local configCard = makeInfoCard(scroll, 128, "CONFIGURATION", 4)
	local syncInterval = makeStepperRow(configCard, 24, "Claim interval", "claimInterval", 1, 10)
	local syncCooldown = makeStepperRow(configCard, 56, "Request cooldown", "pendingCooldown", 3, 30)
	makeButton(configCard, UDim2.new(1, -28, 0, 26), UDim2.new(0, 14, 0, 92), "Unload Kaitun", function()
		Kaitun.detach()
	end)

	local logCard = makeInfoCard(scroll, 170, "ACTIVITY LOG", 5)
	local logLabel = makeText(logCard, UDim2.new(1, -28, 1, -28), UDim2.new(0, 14, 0, 26), 10, PALETTE.text, Enum.Font.Code)

	-- Refresh loop; also unloads when AxionLib is closed.
	task.spawn(function()
		while Kaitun.alive do
			if not hub.alive then
				Kaitun.detach()
				break
			end

			local okText, account = pcall(accountText)
			accountLabel.Text = okText and account or ("error: " .. tostring(account))
			claimLabel.Text = claimText()
			monitorLabel.Text = monitorText()
			logLabel.Text = logText()

			syncMilestones()
			syncDaily()
			syncQuests()
			syncInterval()
			syncCooldown()

			if Kaitun.headerLabel then
				Kaitun.headerLabel.Text = "ANIME ZERO | AFK PROGRESSION SYSTEM"
			end

			task.wait(CONFIG.uiRefresh)
		end
	end)
end

-- Cleanup / unload.

---Stop every worker, listener and Kaitun UI (AxionLib itself is closed by its own button).
function Kaitun.detach()
	if not Kaitun.alive then
		return
	end

	Kaitun.alive = false
	Kaitun.generation += 1

	for _, handle in ipairs(Kaitun.handles) do
		pcall(release, handle)
	end
	table.clear(Kaitun.handles)

	if Kaitun.container then
		pcall(function()
			Kaitun.container:Destroy()
		end)
		Kaitun.container = nil
	end

	if Kaitun.placeholder then
		pcall(function()
			Kaitun.placeholder.Visible = true
		end)
	end

	if Kaitun.headerLabel then
		pcall(function()
			Kaitun.headerLabel.Text = "READY"
		end)
	end
end

-- Entry point.

---Initialize the script.
local function initializeScript()
	local hub, reason = loadAxionLib()
	if not hub then
		error(reason, 0)
	end

	loadModules()
	connectListeners()
	injectUI(hub)
	startClaimWorker()

	logEvent("KAITUN", "init", "Success", State.inLobby and "lobby" or "not in lobby")

	-- Ask the server for the current delivery state (reference script uses action = "refresh").
	local packets = State.modules.LobbyPackets
	if packets and packets.deliveryAction then
		packets.deliveryAction:fire({ action = "refresh", requestId = nextRequestId() })
		logEvent("DELIVERY", "refresh", "Sent")
	end
end

---Called when initialization errors.
---@param err string
local function onInitializeError(err)
	warn("[Kaitun] Failed to initialize.")
	warn(err)
	warn(debug.traceback())
	Kaitun.detach()
end

-- Detach the previous instance before re-initializing.
if shared.AnimeZeroKaitun then
	pcall(shared.AnimeZeroKaitun.detach)
end

shared.AnimeZeroKaitun = Kaitun

xpcall(initializeScript, onInitializeError)
