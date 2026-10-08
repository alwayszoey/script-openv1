-- Check for table that is shared between executions.
if not shared then
	return warn("No shared, no script.")
end

-- Constants.
local HUB_NAME = "PotentHub_UI"
local WINDOW_SIZE = UDim2.new(0, 820, 0, 480)
local SIDEBAR_WIDTH = 180
local HEADER_HEIGHT = 56
local COLUMN_WIDTH = 302
local TOGGLE_KEY = Enum.KeyCode.RightShift

-- Services.
local playersService = game:GetService("Players")
local tweenService = game:GetService("TweenService")
local userInputService = game:GetService("UserInputService")

local localPlayer = playersService.LocalPlayer

local Theme = {
	window = Color3.fromRGB(16, 16, 18),
	sidebar = Color3.fromRGB(11, 11, 13),
	row = Color3.fromRGB(22, 21, 23),
	card = Color3.fromRGB(30, 25, 27),
	control = Color3.fromRGB(38, 36, 39),
	accent = Color3.fromRGB(226, 62, 72),
	accentDark = Color3.fromRGB(96, 26, 34),
	text = Color3.fromRGB(236, 236, 238),
	muted = Color3.fromRGB(150, 150, 156),
	font = Enum.Font.Gotham,
	fontBold = Enum.Font.GothamBold,
	fontMedium = Enum.Font.GothamMedium,
}

local Library = {}
Library.__index = Library

local Column = {}
Column.__index = Column

---Create an instance and assign properties in one call.
---@param className string
---@param properties table
---@param parent Instance?
local function create(className, properties, parent)
	local instance = Instance.new(className)

	for property, value in pairs(properties) do
		instance[property] = value
	end

	instance.Parent = parent
	return instance
end

---Round the corners of an instance.
local function corner(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

---Short tween helper.
local function tween(object, duration, goal)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tweenService:Create(object, info, goal):Play()
end

---Standard text label.
local function label(parent, text, position, size, font, textSize, color, alignment)
	return create("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Position = position,
		Size = size,
		Font = font or Theme.font,
		TextSize = textSize or 12,
		TextColor3 = color or Theme.text,
		TextXAlignment = alignment or Enum.TextXAlignment.Left,
	}, parent)
end

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

---Format seconds as "X Minute(s), Y Second(s)".
local function formatUptime(seconds)
	return string.format("%d Minute(s), %d Second(s)", math.floor(seconds / 60), seconds % 60)
end

---Create the window.
---@param title string
---@param version string
function Library.new(title, version)
	local self = setmetatable({}, Library)
	self.connections = {}
	self.tabs = {}
	self.currentTab = nil
	self.openDropdown = nil
	self.startTime = os.clock()

	local parent = safeParent()
	local old = parent:FindFirstChild(HUB_NAME)
	if old then
		old:Destroy()
	end

	self.gui = create("ScreenGui", {
		Name = HUB_NAME,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = 999,
	}, parent)

	self.window = create("Frame", {
		Name = "Window",
		Size = WINDOW_SIZE,
		Position = UDim2.new(0.5, -410, 0.5, -240),
		BackgroundColor3 = Theme.window,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, self.gui)
	corner(self.window, 10)

	-- Sidebar.
	self.sidebar = create("Frame", {
		Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0),
		BackgroundColor3 = Theme.sidebar,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}, self.window)

	label(self.sidebar, title .. " (" .. version .. ")", UDim2.new(0, 16, 0, 10), UDim2.new(1, -24, 0, 18), Theme.fontMedium, 11, Theme.muted)

	self.tabList = create("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 36),
		Size = UDim2.new(1, 0, 1, -40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, self.sidebar)

	create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, self.tabList)
	create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, self.tabList)

	-- Header.
	self.header = create("Frame", {
		Position = UDim2.new(0, SIDEBAR_WIDTH, 0, 0),
		Size = UDim2.new(1, -SIDEBAR_WIDTH, 0, HEADER_HEIGHT),
		BackgroundTransparency = 1,
	}, self.window)

	label(self.header, "◆", UDim2.new(0, 14, 0, 8), UDim2.new(0, 30, 0, 40), Theme.fontBold, 24, Theme.accent, Enum.TextXAlignment.Center)

	label(self.header, title .. " (Made by you)", UDim2.new(0, 52, 0, 10), UDim2.new(0.6, 0, 0, 18), Theme.fontBold, 13, Theme.text)

	local uptimeLabel = label(self.header, formatUptime(0), UDim2.new(0, 52, 0, 28), UDim2.new(0.6, 0, 0, 16), Theme.font, 11, Theme.muted)

	task.spawn(function()
		while uptimeLabel.Parent do
			uptimeLabel.Text = formatUptime(math.floor(os.clock() - self.startTime))
			task.wait(1)
		end
	end)

	-- Header buttons.
	local function headerButton(text, offset, callback)
		local button = create("TextButton", {
			Size = UDim2.new(0, 28, 0, 28),
			Position = UDim2.new(1, offset, 0, 14),
			BackgroundTransparency = 1,
			Text = text,
			Font = Theme.fontBold,
			TextSize = 15,
			TextColor3 = Theme.muted,
			AutoButtonColor = false,
		}, self.header)

		table.insert(self.connections, button.MouseEnter:Connect(function()
			tween(button, 0.12, { TextColor3 = Theme.text })
		end))
		table.insert(self.connections, button.MouseLeave:Connect(function()
			tween(button, 0.12, { TextColor3 = Theme.muted })
		end))
		table.insert(self.connections, button.MouseButton1Click:Connect(callback))
	end

	headerButton("✕", -38, function()
		self:destroy()
	end)
	headerButton("⌕", -72, function() end)
	headerButton("⚙", -106, function() end)

	-- Window drag via header.
	local dragging, dragStart, startPosition = false, nil, nil

	table.insert(self.connections, self.header.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		dragging = true
		dragStart = input.Position
		startPosition = self.window.Position
	end))

	table.insert(self.connections, userInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local delta = input.Position - dragStart
		self.window.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end))

	table.insert(self.connections, userInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	-- Keybind to hide / show.
	table.insert(self.connections, userInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == TOGGLE_KEY then
			self.window.Visible = not self.window.Visible
		end
	end))

	self.order = 0
	return self
end

---Add a small group heading to the sidebar.
---@param name string
function Library:addGroup(name)
	self.order = self.order + 1

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		LayoutOrder = self.order,
	}, self.tabList)

	label(holder, name, UDim2.new(0, 8, 0, 4), UDim2.new(1, -8, 0, 16), Theme.fontMedium, 11, Theme.muted)
end

---Add a tab with a left and right column.
---@param name string
---@param icon string
function Library:addTab(name, icon)
	self.order = self.order + 1

	local tab = {}

	tab.button = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = Theme.accentDark,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = self.order,
	}, self.tabList)
	corner(tab.button, 6)

	tab.bar = create("Frame", {
		Size = UDim2.new(0, 3, 0, 20),
		Position = UDim2.new(0, 0, 0.5, -10),
		BackgroundColor3 = Theme.accent,
		BorderSizePixel = 0,
		Visible = false,
	}, tab.button)
	corner(tab.bar, 2)

	tab.icon = label(tab.button, icon, UDim2.new(0, 12, 0, 0), UDim2.new(0, 24, 1, 0), Theme.fontBold, 14, Theme.accent, Enum.TextXAlignment.Center)
	tab.name = label(tab.button, name, UDim2.new(0, 46, 0, 0), UDim2.new(1, -50, 1, 0), Theme.fontMedium, 12, Theme.muted)

	tab.page = create("Frame", {
		Position = UDim2.new(0, SIDEBAR_WIDTH, 0, HEADER_HEIGHT),
		Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, -HEADER_HEIGHT),
		BackgroundTransparency = 1,
		Visible = false,
	}, self.window)

	tab.left = Column.new(self, tab.page, 12)
	tab.right = Column.new(self, tab.page, 12 + COLUMN_WIDTH + 12)

	table.insert(self.connections, tab.button.MouseButton1Click:Connect(function()
		self:selectTab(tab)
	end))

	table.insert(self.tabs, tab)

	if not self.currentTab then
		self:selectTab(tab)
	end

	return tab
end

---Switch the visible tab.
function Library:selectTab(selected)
	self.currentTab = selected

	for _, tab in ipairs(self.tabs) do
		local on = tab == selected

		tab.page.Visible = on
		tab.bar.Visible = on
		tab.name.TextColor3 = on and Theme.text or Theme.muted
		tween(tab.button, 0.15, { BackgroundTransparency = on and 0.35 or 1 })
	end
end

---Remove the interface and cleanup.
function Library:destroy()
	for _, connection in ipairs(self.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(self.connections)

	self.gui:Destroy()
end

---Create a scrolling column.
---@param library table
---@param parent Instance
---@param x number
function Column.new(library, parent, x)
	local self = setmetatable({}, Column)
	self.library = library
	self.order = 0

	self.frame = create("ScrollingFrame", {
		Position = UDim2.new(0, x, 0, 0),
		Size = UDim2.new(0, COLUMN_WIDTH, 1, -10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Theme.accent,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, parent)

	create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, self.frame)
	create("UIPadding", { PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6) }, self.frame)

	return self
end

---Create a row frame inside the column.
function Column:row(height, color)
	self.order = self.order + 1

	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = color or Theme.row,
		BorderSizePixel = 0,
		LayoutOrder = self.order,
	}, self.frame)
	corner(row, 6)

	return row
end

---Build a pill switch and return a setter.
function Column:switch(row, default, callback)
	local pill = create("TextButton", {
		Size = UDim2.new(0, 34, 0, 16),
		Position = UDim2.new(1, -46, 0.5, -8),
		BackgroundColor3 = Theme.control,
		Text = "",
		AutoButtonColor = false,
	}, row)
	corner(pill, 999)

	local knob = create("Frame", {
		Size = UDim2.new(0, 12, 0, 12),
		Position = UDim2.new(0, 2, 0.5, -6),
		BackgroundColor3 = Theme.text,
		BorderSizePixel = 0,
	}, pill)
	corner(knob, 999)

	local on = default

	local function apply(instant)
		local pillGoal = { BackgroundColor3 = on and Theme.accent or Theme.control }
		local knobGoal = { Position = on and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6) }

		if instant then
			pill.BackgroundColor3 = pillGoal.BackgroundColor3
			knob.Position = knobGoal.Position
			return
		end

		tween(pill, 0.15, pillGoal)
		tween(knob, 0.15, knobGoal)
	end

	apply(true)

	table.insert(self.library.connections, pill.MouseButton1Click:Connect(function()
		on = not on
		apply()
		if callback then
			callback(on)
		end
	end))

	return function(value)
		on = value
		apply()
	end
end

---Large section header with icon, subtitle and a switch.
function Column:addHeader(icon, title, subtitle, default, callback)
	local row = self:row(50, Theme.card)

	label(row, icon, UDim2.new(0, 12, 0, 0), UDim2.new(0, 26, 1, 0), Theme.fontBold, 18, Theme.accent, Enum.TextXAlignment.Center)
	label(row, title, UDim2.new(0, 48, 0, 8), UDim2.new(1, -110, 0, 16), Theme.fontBold, 13, Theme.text)
	label(row, subtitle, UDim2.new(0, 48, 0, 26), UDim2.new(1, -110, 0, 14), Theme.font, 11, Theme.muted)

	return self:switch(row, default, callback)
end

---Plain row with a switch.
function Column:addToggle(text, default, callback)
	local row = self:row(30)

	label(row, text, UDim2.new(0, 12, 0, 0), UDim2.new(1, -70, 1, 0), Theme.fontMedium, 12, Theme.muted)

	return self:switch(row, default, callback)
end

---Row with a checkbox.
function Column:addCheckbox(text, default, callback)
	local row = self:row(30)

	label(row, text, UDim2.new(0, 12, 0, 0), UDim2.new(1, -50, 1, 0), Theme.fontMedium, 12, Theme.text)

	local box = create("TextButton", {
		Size = UDim2.new(0, 18, 0, 18),
		Position = UDim2.new(1, -32, 0.5, -9),
		BackgroundColor3 = Theme.control,
		Text = "",
		Font = Theme.fontBold,
		TextSize = 13,
		TextColor3 = Theme.text,
		AutoButtonColor = false,
	}, row)
	corner(box, 4)

	local on = default

	local function apply()
		box.Text = on and "✓" or ""
		tween(box, 0.12, { BackgroundColor3 = on and Theme.accent or Theme.control })
	end

	apply()

	table.insert(self.library.connections, box.MouseButton1Click:Connect(function()
		on = not on
		apply()
		if callback then
			callback(on)
		end
	end))

	return function(value)
		on = value
		apply()
	end
end

---Slider with minus / plus buttons.
function Column:addSlider(text, minValue, maxValue, default, suffix, callback)
	local row = self:row(48)

	label(row, text, UDim2.new(0, 12, 0, 6), UDim2.new(0.6, 0, 0, 16), Theme.fontMedium, 12, Theme.muted)

	local valueLabel = label(row, "", UDim2.new(0.4, 0, 0, 6), UDim2.new(0.6, -12, 0, 16), Theme.fontMedium, 12, Theme.text, Enum.TextXAlignment.Right)

	local function stepButton(symbol, position, delta)
		local button = create("TextButton", {
			Size = UDim2.new(0, 18, 0, 18),
			Position = position,
			BackgroundTransparency = 1,
			Text = symbol,
			Font = Theme.fontBold,
			TextSize = 14,
			TextColor3 = Theme.muted,
			AutoButtonColor = false,
		}, row)

		return button, delta
	end

	local minus = stepButton("-", UDim2.new(0, 10, 0, 24), -1)
	local plus = stepButton("+", UDim2.new(1, -28, 0, 24), 1)

	local trackBar = create("TextButton", {
		Size = UDim2.new(1, -72, 0, 8),
		Position = UDim2.new(0, 36, 0, 29),
		BackgroundColor3 = Theme.control,
		Text = "",
		AutoButtonColor = false,
	}, row)
	corner(trackBar, 999)

	local fill = create("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.accent,
		BorderSizePixel = 0,
	}, trackBar)
	corner(fill, 999)

	local knob = create("Frame", {
		Size = UDim2.new(0, 10, 0, 14),
		BackgroundColor3 = Theme.text,
		BorderSizePixel = 0,
	}, trackBar)
	corner(knob, 3)

	local value = default

	local function setValue(newValue, silent)
		value = math.clamp(math.floor(newValue + 0.5), minValue, maxValue)

		local relative = (value - minValue) / (maxValue - minValue)
		fill.Size = UDim2.new(relative, 0, 1, 0)
		knob.Position = UDim2.new(relative, -5, 0.5, -7)
		valueLabel.Text = value .. suffix

		if callback and not silent then
			callback(value)
		end
	end

	setValue(default, true)

	local dragging = false

	local function setFromX(x)
		local relative = math.clamp((x - trackBar.AbsolutePosition.X) / trackBar.AbsoluteSize.X, 0, 1)
		setValue(minValue + relative * (maxValue - minValue))
	end

	table.insert(self.library.connections, trackBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end))

	table.insert(self.library.connections, userInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end))

	table.insert(self.library.connections, userInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	table.insert(self.library.connections, minus.MouseButton1Click:Connect(function()
		setValue(value - 1)
	end))

	table.insert(self.library.connections, plus.MouseButton1Click:Connect(function()
		setValue(value + 1)
	end))

	return setValue
end

---Dropdown with a popup list.
function Column:addDropdown(text, options, default, callback)
	local row = self:row(32)

	label(row, text, UDim2.new(0, 12, 0, 0), UDim2.new(0.4, 0, 1, 0), Theme.fontMedium, 12, Theme.muted)

	local box = create("TextButton", {
		Size = UDim2.new(0, 150, 0, 22),
		Position = UDim2.new(1, -162, 0.5, -11),
		BackgroundColor3 = Theme.control,
		Text = "  " .. tostring(default),
		Font = Theme.font,
		TextSize = 12,
		TextColor3 = Theme.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
	}, row)
	corner(box, 4)

	label(box, "v", UDim2.new(1, -20, 0, 0), UDim2.new(0, 14, 1, 0), Theme.font, 11, Theme.muted, Enum.TextXAlignment.Center)

	local library = self.library

	local function closeList()
		if library.openDropdown then
			library.openDropdown:Destroy()
			library.openDropdown = nil
		end
	end

	table.insert(library.connections, box.MouseButton1Click:Connect(function()
		local wasOpen = library.openDropdown ~= nil
		closeList()
		if wasOpen then
			return
		end

		local list = create("Frame", {
			Position = UDim2.fromOffset(box.AbsolutePosition.X, box.AbsolutePosition.Y + box.AbsoluteSize.Y + 2),
			Size = UDim2.new(0, box.AbsoluteSize.X, 0, #options * 24 + 4),
			BackgroundColor3 = Theme.sidebar,
			BorderSizePixel = 0,
			ZIndex = 100,
		}, library.gui)
		corner(list, 4)

		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)
		create("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }, list)

		for _, option in ipairs(options) do
			local item = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Text = "  " .. tostring(option),
				Font = Theme.font,
				TextSize = 12,
				TextColor3 = Theme.text,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				ZIndex = 101,
			}, list)

			item.MouseEnter:Connect(function()
				item.TextColor3 = Theme.accent
			end)
			item.MouseLeave:Connect(function()
				item.TextColor3 = Theme.text
			end)
			item.MouseButton1Click:Connect(function()
				box.Text = "  " .. tostring(option)
				closeList()
				if callback then
					callback(option)
				end
			end)
		end

		library.openDropdown = list
	end))
end

---Muted info line.
function Column:addLabel(text)
	local row = self:row(26, Theme.window)
	row.BackgroundTransparency = 1

	return label(row, text, UDim2.new(0, 12, 0, 0), UDim2.new(1, -12, 1, 0), Theme.font, 11, Theme.muted)
end

-- Detach the previous execution before starting a new one.
if shared.PotentUI then
	pcall(function()
		shared.PotentUI:destroy()
	end)
end

-- Demo window. Replace the callbacks with your own logic.
local Settings = {}

local window = Library.new("Project Hub", "v0.1.0")
shared.PotentUI = window

window:addGroup("Farming")

local farm = window:addTab("Auto Farm", "✖")
window:addTab("Farm Entity", "⚔")
window:addTab("Fishing", "🎣")
window:addTab("Dungeon", "☠")
window:addTab("Miscellaneous", "❖")

window:addGroup("Combat")
window:addTab("Slayers", "✖")
window:addTab("Demon", "♨")

window:addGroup("Players")
window:addTab("Equipment", "✋")
window:addTab("Character", "☺")

-- Left column.
farm.left:addHeader("⚙", "Final Selection", "Auto Final Selection", true, function(value)
	Settings.finalSelection = value
end)
farm.left:addLabel("⏳ Next Final Selection in 1 Hours 59 Minutes")
farm.left:addToggle("Auto Final Selection", false, function(value)
	Settings.autoFinal = value
end)
farm.left:addToggle("Auto Farm Lost", false, function(value)
	Settings.autoLost = value
end)

farm.left:addHeader("✖", "Auto Farm Level", "From level 0 - MAX", true, function(value)
	Settings.farmLevel = value
end)
farm.left:addToggle("Auto Farm Level", false, function(value)
	Settings.autoLevel = value
end)
farm.left:addCheckbox("Instant Kill", true, function(value)
	Settings.instantKill = value
end)
farm.left:addDropdown("Weapon Slot", { "1", "2", "3", "4" }, "1", function(value)
	Settings.weaponSlot = value
end)
farm.left:addDropdown("Attack Method", { "Above", "Below", "Behind" }, "Above", function(value)
	Settings.attackMethod = value
end)
farm.left:addSlider("Attack Distance", 1, 30, 5, " studs", function(value)
	Settings.attackDistance = value
end)

-- Right column.
farm.right:addSlider("Nearby Entity Distance", 10, 300, 100, " studs", function(value)
	Settings.entityDistance = value
end)
farm.right:addSlider("Max Drop Chest Distance", 10, 300, 100, " studs", function(value)
	Settings.chestDistance = value
end)

farm.right:addHeader("✧", "Auto Skills", "Auto Use Skills", true, function(value)
	Settings.autoSkills = value
end)
farm.right:addCheckbox("Enabled", true, function(value)
	Settings.skillsEnabled = value
end)
farm.right:addCheckbox("Auto Active Clan Skill", true, function(value)
	Settings.clanSkill = value
end)
farm.right:addDropdown("Select Skills", { "Z", "X", "C", "V" }, "...", function(value)
	Settings.selectedSkill = value
end)
farm.right:addSlider("Hold (Z)", 0, 10, 0, "s", function(value)
	Settings.holdZ = value
end)
farm.right:addSlider("Hold (X)", 0, 10, 0, "s", function(value)
	Settings.holdX = value
end)
farm.right:addSlider("Hold (C)", 0, 10, 0, "s", function(value)
	Settings.holdC = value
end)
