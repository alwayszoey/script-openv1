
--[[
    AxionHub v23 - Delta UI Recovery
    Standalone Luau
    Features:
      - Responsive purple UI
      - Home / Servers / Settings
      - Server Hop / Rejoin / Copy Job ID
      - Optional Icons.lua loader
      - RightShift toggle
      - Error reporting and cleanup

    Note:
      Roblox does not expose a universal API for discovering
      historical game versions across every experience.
]]

if not shared then
    return warn("[AxionHub] shared is unavailable")
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer

local OLD = shared.AxionHub
if type(OLD) == "table" and type(OLD.Destroy) == "function" then
    pcall(function()
        OLD:Destroy()
    end)
end

local Hub = {
    Alive = true,
    Connections = {},
    GUI = nil,
    Page = "HOME",
    Busy = false,
}

shared.AxionHub = Hub

local C = {
    Background = Color3.fromRGB(10, 5, 20),
    Panel = Color3.fromRGB(24, 12, 42),
    Card = Color3.fromRGB(35, 19, 58),
    Accent = Color3.fromRGB(132, 72, 255),
    Accent2 = Color3.fromRGB(190, 90, 255),
    Text = Color3.fromRGB(245, 240, 255),
    Muted = Color3.fromRGB(165, 150, 190),
    Green = Color3.fromRGB(110, 245, 170),
    Red = Color3.fromRGB(255, 105, 130),
}

local ICONS_URL =
    "https://raw.githubusercontent.com/alwayszoey/script-openv1/refs/heads/main/assets/dist/Icons.lua"

local Icons = {}

local function addConnection(connection)
    table.insert(Hub.Connections, connection)
    return connection
end

local function disconnectAll()
    for _, connection in ipairs(Hub.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(Hub.Connections)
end

function Hub:Destroy()
    self.Alive = false
    disconnectAll()

    if self.GUI then
        pcall(function()
            self.GUI:Destroy()
        end)
        self.GUI = nil
    end
end

local function getParent()
    if type(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then
            return result
        end
    end

    local playerGui = LP:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        return playerGui
    end

    return game:GetService("CoreGui")
end

local function loadIcons()
    if type(request) ~= "function" then
        warn("[AxionHub] request() unavailable; using built-in UI")
        return
    end

    local ok, response = pcall(function()
        return request({
            Url = ICONS_URL,
            Method = "GET",
        })
    end)

    if not ok or type(response) ~= "table"
        or not response.Success
        or type(response.Body) ~= "string" then
        warn("[AxionHub] Icons.lua unavailable; using built-in UI")
        return
    end

    if type(loadstring) ~= "function" then
        return
    end

    local compiled, chunk = pcall(loadstring, response.Body)
    if not compiled or type(chunk) ~= "function" then
        warn("[AxionHub] Icons.lua could not be compiled")
        return
    end

    local ran, result = pcall(chunk)
    if ran and type(result) == "table" then
        Icons = result
    end
end

local function create(className, props, parent)
    local obj = Instance.new(className)

    for key, value in pairs(props or {}) do
        local ok, err = pcall(function()
            obj[key] = value
        end)

        if not ok then
            warn("[AxionHub] Property " .. key .. ": " .. tostring(err))
        end
    end

    obj.Parent = parent
    return obj
end

local function corner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius or 10),
    }, parent)
end

local function stroke(parent, color, transparency)
    return create("UIStroke", {
        Color = color or C.Accent,
        Transparency = transparency or 0.4,
        Thickness = 1,
    }, parent)
end

local function label(parent, text, size, position, textSize, color, bold)
    return create("TextLabel", {
        BackgroundTransparency = 1,
        Size = size,
        Position = position,
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        Text = text,
        TextSize = textSize or 12,
        TextColor3 = color or C.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = true,
    }, parent)
end

local function button(parent, text, position, size, callback)
    local b = create("TextButton", {
        Size = size,
        Position = position,
        BackgroundColor3 = C.Card,
        BorderSizePixel = 0,
        AutoButtonColor = true,
        Text = text,
        TextColor3 = C.Text,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
    }, parent)

    corner(b, 9)
    stroke(b, C.Accent, 0.65)

    addConnection(b.Activated:Connect(function()
        if Hub.Alive and callback then
            local ok, err = pcall(callback)
            if not ok then
                warn("[AxionHub] Button error: " .. tostring(err))
            end
        end
    end))

    return b
end

local root
local content
local toastLabel
local pages = {}
local navButtons = {}
local statusLabel
local serverCountLabel

local function notify(message, color)
    if toastLabel and toastLabel.Parent then
        toastLabel.Text = tostring(message)
        toastLabel.TextColor3 = color or C.Text
    end
end

local function showPage(name)
    Hub.Page = name

    for pageName, frame in pairs(pages) do
        frame.Visible = pageName == name
    end

    for pageName, b in pairs(navButtons) do
        b.BackgroundColor3 =
            pageName == name and C.Accent or C.Card
    end
end

local function createPage(name)
    local frame = create("ScrollingFrame", {
        Name = name,
        Size = UDim2.new(1, -170, 1, -80),
        Position = UDim2.new(0, 155, 0, 65),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, root)

    create("UIPadding", {
        PaddingBottom = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 8),
    }, frame)

    create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, frame)

    pages[name] = frame
    return frame
end

local function makeCard(parent, title, height)
    local card = create("Frame", {
        Size = UDim2.new(1, -4, 0, height or 100),
        BackgroundColor3 = C.Panel,
        BorderSizePixel = 0,
    }, parent)

    corner(card, 12)
    stroke(card, C.Accent, 0.78)

    label(card, title, UDim2.new(1, -24, 0, 28),
        UDim2.new(0, 12, 0, 5), 13, C.Accent2, true)

    return card
end

local function makeAction(parent, title, description, callback)
    local card = makeCard(parent, title, 76)

    label(card, description,
        UDim2.new(0.58, -16, 0, 32),
        UDim2.new(0, 12, 0, 34), 10, C.Muted)

    button(card, "RUN",
        UDim2.new(1, -86, 0, 35),
        UDim2.new(0, 72, 0, 30),
        callback)

    return card
end

local function getServerList()
    if type(request) ~= "function" then
        return nil, "This executor does not expose request()"
    end

    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
        game.PlaceId
    )

    local all = {}
    local cursor = nil

    for _ = 1, 3 do
        if cursor then
            url = string.format(
                "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
                game.PlaceId,
                HttpService:UrlEncode(cursor)
            )
        end

        local ok, response = pcall(function()
            return request({
                Url = url,
                Method = "GET",
            })
        end)

        if not ok or not response or not response.Success then
            return nil, "Server API request failed"
        end

        local decoded, data = pcall(function()
            return HttpService:JSONDecode(response.Body)
        end)

        if not decoded or type(data) ~= "table"
            or type(data.data) ~= "table" then
            return nil, "Invalid server API response"
        end

        for _, server in ipairs(data.data) do
            if server.id
                and server.id ~= game.JobId
                and type(server.playing) == "number"
                and type(server.maxPlayers) == "number"
                and server.playing < server.maxPlayers then
                table.insert(all, server)
            end
        end

        cursor = data.nextPageCursor
        if not cursor then
            break
        end
    end

    return all
end

local function teleportToServer(serverId)
    if Hub.Busy then
        notify("Teleport already in progress", C.Muted)
        return
    end

    Hub.Busy = true
    notify("Requesting teleport...", C.Accent2)

    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(
            game.PlaceId,
            serverId,
            LP
        )
    end)

    if not ok then
        Hub.Busy = false
        notify("Teleport failed: " .. tostring(err), C.Red)
        return
    end

    notify("Teleport requested", C.Green)
end

local function serverHop()
    notify("Searching public servers...", C.Accent2)

    task.spawn(function()
        local servers, err = getServerList()

        if not Hub.Alive then
            return
        end

        if not servers then
            notify(err or "Search failed", C.Red)
            return
        end

        if #servers == 0 then
            notify("No other public server found", C.Red)
            return
        end

        local target = servers[math.random(1, #servers)]

        if serverCountLabel then
            serverCountLabel.Text =
                string.format("Available servers: %d", #servers)
        end

        teleportToServer(target.id)
    end)
end

local function rejoin()
    if Hub.Busy then
        notify("Teleport already in progress", C.Muted)
        return
    end

    Hub.Busy = true
    notify("Rejoining current server...", C.Accent2)

    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(
            game.PlaceId,
            game.JobId,
            LP
        )
    end)

    if not ok then
        Hub.Busy = false
        notify("Rejoin failed: " .. tostring(err), C.Red)
    end
end

local function copyJobId()
    if type(setclipboard) ~= "function" then
        notify("Clipboard API unavailable", C.Red)
        return
    end

    if game.JobId == "" then
        notify("Job ID unavailable", C.Red)
        return
    end

    local ok = pcall(setclipboard, game.JobId)
    notify(ok and "Job ID copied" or "Copy failed",
        ok and C.Green or C.Red)
end

local function buildUI()
    local gui = create("ScreenGui", {
        Name = "AxionHub_v23",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999,
    }, getParent())

    Hub.GUI = gui

    root = create("Frame", {
        Name = "MainWindow",
        Size = UDim2.new(0, 580, 0, 390),
        Position = UDim2.new(0.5, -290, 0.5, -195),
        BackgroundColor3 = C.Background,
        BorderSizePixel = 0,
        Active = true,
    }, gui)

    corner(root, 14)
    stroke(root, C.Accent, 0.15)

    local scale = create("UIScale", {
        Scale = 1,
    }, root)

    local function resize()
        local camera = workspace.CurrentCamera
        if not camera then
            return
        end

        local v = camera.ViewportSize
        scale.Scale = math.clamp(
            math.min((v.X - 20) / 580, (v.Y - 20) / 390),
            0.45,
            1
        )
    end

    resize()

    if workspace.CurrentCamera then
        addConnection(
            workspace.CurrentCamera:GetPropertyChangedSignal(
                "ViewportSize"
            ):Connect(resize)
        )
    end

    local sidebar = create("Frame", {
        Size = UDim2.new(0, 145, 1, 0),
        BackgroundColor3 = C.Panel,
        BorderSizePixel = 0,
    }, root)

    corner(sidebar, 14)

    label(sidebar, "AXION", UDim2.new(1, -20, 0, 32),
        UDim2.new(0, 14, 0, 14), 21, C.Text, true)

    label(sidebar, "H U B   v23", UDim2.new(1, -20, 0, 18),
        UDim2.new(0, 14, 0, 45), 10, C.Accent2, true)

    local navItems = {
        {"HOME", "Home"},
        {"SERVERS", "Servers"},
        {"SETTINGS", "Settings"},
    }

    for index, item in ipairs(navItems) do
        local name, title = item[1], item[2]

        local b = button(
            sidebar,
            title,
            UDim2.new(0, 10, 0, 90 + (index - 1) * 47),
            UDim2.new(1, -20, 0, 38),
            function()
                showPage(name)
            end
        )

        navButtons[name] = b
    end

    button(sidebar, "CLOSE",
        UDim2.new(0, 10, 1, -48),
        UDim2.new(1, -20, 0, 34),
        function()
            Hub:Destroy()
        end)

    label(root, "AXION HUB",
        UDim2.new(0, 220, 0, 25),
        UDim2.new(0, 160, 0, 16), 16, C.Text, true)

    toastLabel = label(root, "Ready",
        UDim2.new(0, 245, 0, 20),
        UDim2.new(1, -255, 0, 18), 10, C.Green)

    -- HOME
    local home = createPage("HOME")

    local welcome = makeCard(home, "WELCOME", 94)
    label(welcome, "Player: " .. LP.Name,
        UDim2.new(1, -24, 0, 20),
        UDim2.new(0, 12, 0, 36), 12, C.Text)

    label(welcome, "Place ID: " .. tostring(game.PlaceId),
        UDim2.new(1, -24, 0, 20),
        UDim2.new(0, 12, 0, 59), 11, C.Muted)

    local serverInfo = makeCard(home, "CURRENT SESSION", 82)
    label(serverInfo, "Job ID: " ..
        (game.JobId ~= "" and game.JobId or "Unavailable"),
        UDim2.new(1, -24, 0, 38),
        UDim2.new(0, 12, 0, 34), 10, C.Muted)

    makeAction(home, "SERVER HOP",
        "Find another public server",
        serverHop)

    makeAction(home, "REJOIN",
        "Request to join this server again",
        rejoin)

    -- SERVERS
    local serverPage = createPage("SERVERS")

    local searchCard = makeCard(serverPage, "PUBLIC SERVER SEARCH", 120)

    label(searchCard,
        "Searches public servers for this Place. Historical game versions cannot be verified by this endpoint.",
        UDim2.new(1, -24, 0, 44),
        UDim2.new(0, 12, 0, 32), 10, C.Muted)

    button(searchCard, "SEARCH & HOP",
        UDim2.new(0, 12, 0, 78),
        UDim2.new(0, 145, 0, 30),
        serverHop)

    local countCard = makeCard(serverPage, "SEARCH RESULT", 66)
    serverCountLabel = label(countCard, "Available servers: not searched",
        UDim2.new(1, -24, 0, 24),
        UDim2.new(0, 12, 0, 33), 11, C.Text)

    makeAction(serverPage, "COPY JOB ID",
        "Copy the current server instance ID",
        copyJobId)

    -- SETTINGS
    local settings = createPage("SETTINGS")

    local about = makeCard(settings, "ABOUT", 105)

    label(about,
        "AxionHub v23\nStandalone UI recovery build\nRightShift toggles the window.",
        UDim2.new(1, -24, 0, 66),
        UDim2.new(0, 12, 0, 33), 11, C.Muted)

    makeAction(settings, "REJOIN CURRENT SERVER",
        "Attempt to return to this instance",
        rejoin)

    makeAction(settings, "DESTROY UI",
        "Close the hub and disconnect UI events",
        function()
            Hub:Destroy()
        end)

    showPage("HOME")

    -- Drag window using its title area.
    local dragging = false
    local dragStart
    local startPosition

    local dragBar = create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -160, 0, 52),
        Position = UDim2.new(0, 150, 0, 0),
        AutoButtonColor = false,
        Active = true,
    }, root)

    addConnection(dragBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = root.Position
        end
    end))

    addConnection(UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            root.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end))

    addConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    local minimized = false

    button(root, "—",
        UDim2.new(1, -65, 0, 12),
        UDim2.new(0, 24, 0, 24),
        function()
            minimized = not minimized

            for _, child in ipairs(root:GetChildren()) do
                if child ~= scale and child ~= sidebar then
                    if child:IsA("GuiObject") then
                        child.Visible = not minimized
                    end
                end
            end

            root.Size = minimized
                and UDim2.new(0, 145, 0, 62)
                or UDim2.new(0, 580, 0, 390)

            sidebar.Visible = not minimized
        end)

    addConnection(UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not Hub.Alive then
            return
        end

        if input.KeyCode == Enum.KeyCode.RightShift then
            root.Visible = not root.Visible
        end
    end))

    return gui
end

-- Optional icon library: UI remains usable if this fails.
task.spawn(function()
    local ok, err = xpcall(function()
        loadIcons()
        if Hub.Alive then
            buildUI()
        end
    end, function(message)
        return debug.traceback(tostring(message), 2)
    end)

    if not ok then
        warn("[AxionHub] Initialization failed:\n" .. tostring(err))

        if Hub.GUI then
            pcall(function()
                Hub.GUI:Destroy()
            end)
        end
    end
end)

print("[AxionHub] v23 loaded")
