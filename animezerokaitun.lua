--[[
    animezerokaitun.lua
    Single-file Anime Zero automation UI

    Notes:
    - Uses a self-contained UI; no separate module files required.
    - Only performs client-side character/NPC discovery and optional movement/tool activation.
    - Game-specific RemoteEvent calls are intentionally NOT guessed.
      The supplied dump lists remote names, but does not establish argument signatures.
    - Use only where permitted by the game and platform rules.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Stop an earlier copy if this script is re-executed.
if getgenv and getgenv().AnimeZeroKaitun_Stop then
    pcall(getgenv().AnimeZeroKaitun_Stop)
end

local State = {
    Running = true,
    AutoFarm = false,
    AutoEquip = true,
    AutoUseTool = false,
    AutoReroll = false,
    AutoTrait = false,
    AutoDaily = false,
    AutoQuest = false,
    AutoMilestones = false,
    FarmRadius = 350,
    MoveOffset = 5,
    TargetName = "",
    Status = "Ready",
    Connections = {},
    LastAction = 0,
    ActionCooldown = 1.25,
}

local function safeDisconnectAll()
    for _, connection in ipairs(State.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(State.Connections)
end

local oldGui = PlayerGui:FindFirstChild("AnimeZeroKaitunUI")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "AnimeZeroKaitunUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(470, 410)
main.Position = UDim2.new(0.5, -235, 0.5, -205)
main.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
main.BorderSizePixel = 0
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(106, 76, 220)
stroke.Thickness = 1.4
stroke.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 48)
header.BackgroundColor3 = Color3.fromRGB(24, 25, 38)
header.BorderSizePixel = 0
header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local headerCover = Instance.new("Frame")
headerCover.Size = UDim2.new(1, 0, 0, 12)
headerCover.Position = UDim2.new(0, 0, 1, -12)
headerCover.BackgroundColor3 = header.BackgroundColor3
headerCover.BorderSizePixel = 0
headerCover.Parent = header

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(15, 5)
title.Size = UDim2.new(1, -80, 0, 23)
title.Font = Enum.Font.GothamBold
title.Text = "ANIME ZERO  /  KAITUN"
title.TextColor3 = Color3.fromRGB(245, 245, 255)
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(16, 27)
subtitle.Size = UDim2.new(1, -90, 0, 15)
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "Single-file control panel"
subtitle.TextColor3 = Color3.fromRGB(153, 156, 177)
subtitle.TextSize = 10
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(30, 30)
close.Position = UDim2.new(1, -39, 0, 9)
close.BackgroundColor3 = Color3.fromRGB(48, 39, 65)
close.Text = "×"
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.Font = Enum.Font.GothamBold
close.TextSize = 21
close.AutoButtonColor = true
close.Parent = header
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)

local tabBar = Instance.new("Frame")
tabBar.BackgroundTransparency = 1
tabBar.Position = UDim2.fromOffset(12, 58)
tabBar.Size = UDim2.new(1, -24, 0, 32)
tabBar.Parent = main

local content = Instance.new("ScrollingFrame")
content.Position = UDim2.fromOffset(12, 98)
content.Size = UDim2.new(1, -24, 1, -145)
content.BackgroundColor3 = Color3.fromRGB(20, 22, 31)
content.BorderSizePixel = 0
content.ScrollBarThickness = 4
content.ScrollBarImageColor3 = Color3.fromRGB(106, 76, 220)
content.CanvasSize = UDim2.new()
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = main
Instance.new("UICorner", content).CornerRadius = UDim.new(0, 9)

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop = UDim.new(0, 10)
contentPadding.PaddingBottom = UDim.new(0, 10)
contentPadding.PaddingLeft = UDim.new(0, 10)
contentPadding.PaddingRight = UDim.new(0, 10)
contentPadding.Parent = content

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 7)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = content

local footer = Instance.new("TextLabel")
footer.Position = UDim2.new(0, 14, 1, -36)
footer.Size = UDim2.new(1, -28, 0, 24)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.Gotham
footer.Text = "STATUS: Ready"
footer.TextColor3 = Color3.fromRGB(180, 180, 201)
footer.TextSize = 11
footer.TextXAlignment = Enum.TextXAlignment.Left
footer.Parent = main

local function setStatus(text)
    State.Status = text
    if footer and footer.Parent then
        footer.Text = "STATUS: " .. tostring(text)
    end
end

local function makeSection(text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -2, 0, 22)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.Text = string.upper(text)
    label.TextColor3 = Color3.fromRGB(176, 153, 255)
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = content
    return label
end

local function makeToggle(labelText, key, defaultValue, note)
    State[key] = defaultValue
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -2, 0, note and 48 or 38)
    row.BackgroundColor3 = Color3.fromRGB(29, 31, 43)
    row.BorderSizePixel = 0
    row.Parent = content
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(10, note and 5 or 0)
    label.Size = UDim2.new(1, -82, 0, note and 19 or 38)
    label.Font = Enum.Font.GothamMedium
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(235, 235, 245)
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    if note then
        local detail = Instance.new("TextLabel")
        detail.BackgroundTransparency = 1
        detail.Position = UDim2.fromOffset(10, 24)
        detail.Size = UDim2.new(1, -18, 0, 17)
        detail.Font = Enum.Font.Gotham
        detail.Text = note
        detail.TextColor3 = Color3.fromRGB(147, 151, 171)
        detail.TextSize = 9
        detail.TextXAlignment = Enum.TextXAlignment.Left
        detail.Parent = row
    end

    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(52, 24)
    button.Position = UDim2.new(1, -62, 0, note and 7 or 7)
    button.BackgroundColor3 = defaultValue and Color3.fromRGB(104, 74, 213) or Color3.fromRGB(57, 59, 72)
    button.Text = defaultValue and "ON" or "OFF"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 10
    button.Parent = row
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)

    button.MouseButton1Click:Connect(function()
        State[key] = not State[key]
        button.Text = State[key] and "ON" or "OFF"
        button.BackgroundColor3 = State[key] and Color3.fromRGB(104, 74, 213) or Color3.fromRGB(57, 59, 72)
        setStatus(labelText .. (State[key] and " enabled" or " disabled"))
        if (key == "AutoReroll" or key == "AutoTrait" or key == "AutoDaily"
            or key == "AutoQuest" or key == "AutoMilestones") and State[key] then
            setStatus(labelText .. " selected; remote parameters not verified")
        end
    end)
    return row
end

local function makeButton(text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -2, 0, 34)
    button.BackgroundColor3 = Color3.fromRGB(72, 54, 143)
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 11
    button.Parent = content
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)
    button.MouseButton1Click:Connect(callback)
    return button
end

local function makeSlider(labelText, minValue, maxValue, initial, onChanged)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -2, 0, 52)
    row.BackgroundColor3 = Color3.fromRGB(29, 31, 43)
    row.BorderSizePixel = 0
    row.Parent = content
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(10, 4)
    label.Size = UDim2.new(1, -20, 0, 18)
    label.Font = Enum.Font.GothamMedium
    label.Text = labelText .. ": " .. tostring(initial)
    label.TextColor3 = Color3.fromRGB(235, 235, 245)
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local bar = Instance.new("Frame")
    bar.Position = UDim2.fromOffset(10, 30)
    bar.Size = UDim2.new(1, -20, 0, 6)
    bar.BackgroundColor3 = Color3.fromRGB(58, 59, 76)
    bar.BorderSizePixel = 0
    bar.Parent = row
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((initial - minValue) / (maxValue - minValue), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(128, 96, 245)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local hit = Instance.new("TextButton")
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.Size = UDim2.new(1, 0, 0, 24)
    hit.Position = UDim2.new(0, 0, 0, -9)
    hit.Parent = bar

    local dragging = false
    local function update(x)
        local ratio = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(minValue + (maxValue - minValue) * ratio)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        label.Text = labelText .. ": " .. tostring(value)
        onChanged(value)
    end
    hit.MouseButton1Down:Connect(function()
        dragging = true
        update(UserInputService:GetMouseLocation().X)
    end)
    table.insert(State.Connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            update(input.Position.X)
        end
    end))
    table.insert(State.Connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getRoot(character)
    return character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
end

local function getHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function isAliveModel(model)
    if not model or not model:IsA("Model") or model == getCharacter() then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    local root = getRoot(model)
    return hum ~= nil and hum.Health > 0 and root ~= nil
end

local function findNearestTarget()
    local character = getCharacter()
    local root = getRoot(character)
    if not root then return nil end

    local best, bestDistance = nil, State.FarmRadius
    local function consider(model)
        if not isAliveModel(model) then return end
        if Players:GetPlayerFromCharacter(model) then return end
        local targetRoot = getRoot(model)
        local distance = (targetRoot.Position - root.Position).Magnitude
        if distance < bestDistance then
            best, bestDistance = model, distance
        end
    end

    -- Search common NPC containers first, then workspace descendants as fallback.
    local seen = {}
    for _, name in ipairs({"Enemies", "Mobs", "NPCs", "EnemiesFolder", "Monsters"}) do
        local folder = Workspace:FindFirstChild(name, true)
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                if not seen[obj] then
                    seen[obj] = true
                    consider(obj)
                end
            end
        end
    end

    if not best then
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and not seen[obj] then consider(obj) end
        end
    end
    return best
end

local function equipFirstTool()
    local character = getCharacter()
    local humanoid = getHumanoid(character)
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not character or not humanoid or not backpack then return false end
    local equipped = character:FindFirstChildOfClass("Tool")
    if equipped then return true end
    local tool = backpack:FindFirstChildOfClass("Tool")
    if tool then
        pcall(function() humanoid:EquipTool(tool) end)
        return true
    end
    return false
end

local function moveNearTarget(target)
    local character = getCharacter()
    local root = getRoot(character)
    local humanoid = getHumanoid(character)
    local targetRoot = getRoot(target)
    if not root or not humanoid or not targetRoot then return false end

    local distance = (targetRoot.Position - root.Position).Magnitude
    if distance > 14 then
        -- Use a short path to approach the NPC rather than teleporting.
        local path
        local ok = pcall(function()
            path = PathfindingService:CreatePath({
                AgentRadius = 2,
                AgentHeight = 5,
                AgentCanJump = true,
            })
            path:ComputeAsync(root.Position, targetRoot.Position)
        end)

        if ok and path and path.Status == Enum.PathStatus.Success then
            local waypoints = path:GetWaypoints()
            local waypoint = waypoints[math.min(2, #waypoints)]
            if waypoint then
                if waypoint.Action == Enum.PathWaypointAction.Jump then
                    humanoid.Jump = true
                end
                humanoid:MoveTo(waypoint.Position)
            end
        else
            humanoid:MoveTo(targetRoot.Position + Vector3.new(0, 0, State.MoveOffset))
        end
    end
    return true
end

local function useEquippedTool()
    local character = getCharacter()
    if not character then return end
    local tool = character:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
end

-- Pages are local UI views; switching pages does not start actions.
local currentTab = "FARM"
local tabButtons = {}
local function clearContent()
    for _, child in ipairs(content:GetChildren()) do
        if not child:IsA("UIPadding") and not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
end

local function buildFarmPage()
    clearContent()
    makeSection("Combat / Farming")
    makeToggle("Auto Farm (nearest NPC)", "AutoFarm", false, "Finds nearby NPCs and approaches them.")
    makeToggle("Auto Equip Tool", "AutoEquip", true, "Equips the first available Tool.")
    makeToggle("Auto Activate Tool", "AutoUseTool", false, "Activates the equipped Tool; depends on game combat.")
    makeSlider("NPC search radius", 50, 1000, State.FarmRadius, function(v) State.FarmRadius = v end)
    makeButton("Find nearest NPC", function()
        local target = findNearestTarget()
        if target then
            State.TargetName = target.Name
            setStatus("Target found: " .. target.Name)
        else
            setStatus("No NPC found in range")
        end
    end)
    makeButton("Stop all automation", function()
        State.AutoFarm = false
        State.AutoUseTool = false
        setStatus("Automation stopped")
    end)
end

local function buildRerollPage()
    clearContent()
    makeSection("Character / Trait Reroll")
    makeToggle("Auto Character Reroll", "AutoReroll", false,
        "Not executed: RollCharacter arguments are not verified.")
    makeToggle("Auto Trait Reroll", "AutoTrait", false,
        "Not executed: RollTrait arguments are not verified.")
    makeButton("Reroll diagnostics", function()
        setStatus("Remote names found; payload/signatures still unverified")
    end)
    makeSection("Why reroll is gated")
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -2, 0, 72)
    info.BackgroundColor3 = Color3.fromRGB(29, 31, 43)
    info.BorderSizePixel = 0
    info.Font = Enum.Font.Gotham
    info.Text = "The dump shows the RemoteEvent names but not reliable call sites or argument types. This panel does not spam or guess server calls. Once the correct argument format is confirmed, this can be wired to the game's real reroll flow."
    info.TextColor3 = Color3.fromRGB(190, 191, 207)
    info.TextSize = 11
    info.TextWrapped = true
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextYAlignment = Enum.TextYAlignment.Top
    info.Parent = content
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 9)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 9)
    pad.PaddingRight = UDim.new(0, 9)
    pad.Parent = info
end

local function buildRewardsPage()
    clearContent()
    makeSection("Rewards / Progression")
    makeToggle("Auto Daily Reward", "AutoDaily", false,
        "Visible toggle only until claim flow is confirmed.")
    makeToggle("Auto Quest Rewards", "AutoQuest", false,
        "Visible toggle only until claim flow is confirmed.")
    makeToggle("Auto Level Milestones", "AutoMilestones", false,
        "Visible toggle only until claim flow is confirmed.")
    makeButton("Progression diagnostics", function()
        setStatus("Reward remotes identified; call signatures unverified")
    end)
    makeSection("Detected remote names")
    local names = Instance.new("TextLabel")
    names.Size = UDim2.new(1, -2, 0, 70)
    names.BackgroundColor3 = Color3.fromRGB(29, 31, 43)
    names.BorderSizePixel = 0
    names.Font = Enum.Font.Code
    names.Text = "ClaimDailyReward\\nClaimQuestReward / ClaimQuestRewards\\nClaimLevelMilestone / ClaimAchievementRewards"
    names.TextColor3 = Color3.fromRGB(190, 191, 207)
    names.TextSize = 10
    names.TextWrapped = true
    names.TextXAlignment = Enum.TextXAlignment.Left
    names.TextYAlignment = Enum.TextYAlignment.Center
    names.Parent = content
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 9)
    pad.Parent = names
end

local function buildSettingsPage()
    clearContent()
    makeSection("Settings")
    makeButton("Reset UI position", function()
        main.Position = UDim2.new(0.5, -235, 0.5, -205)
        setStatus("UI position reset")
    end)
    makeButton("Show detected remotes", function()
        setStatus("RollCharacter, RollTrait, ClaimDailyReward, ClaimQuestRewards")
    end)
    makeButton("Unload script", function()
        State.Running = false
        State.AutoFarm = false
        State.AutoUseTool = false
        safeDisconnectAll()
        if gui then gui:Destroy() end
        if getgenv then getgenv().AnimeZeroKaitun_Stop = nil end
    end)
    makeSection("Safety")
    local note = Instance.new("TextLabel")
    note.Size = UDim2.new(1, -2, 0, 72)
    note.BackgroundColor3 = Color3.fromRGB(29, 31, 43)
    note.BorderSizePixel = 0
    note.Font = Enum.Font.Gotham
    note.Text = "No guessed server payloads, remote spam, or teleport exploits are included. Auto Farm uses normal Humanoid movement and Tool activation only."
    note.TextColor3 = Color3.fromRGB(190, 191, 207)
    note.TextSize = 11
    note.TextWrapped = true
    note.TextXAlignment = Enum.TextXAlignment.Left
    note.TextYAlignment = Enum.TextYAlignment.Top
    note.Parent = content
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 9)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 9)
    pad.PaddingRight = UDim.new(0, 9)
    pad.Parent = note
end

local pages = {
    FARM = buildFarmPage,
    REROLL = buildRerollPage,
    REWARDS = buildRewardsPage,
    SETTINGS = buildSettingsPage,
}

local function switchTab(name)
    currentTab = name
    for tabName, button in pairs(tabButtons) do
        button.BackgroundColor3 = tabName == name and Color3.fromRGB(104, 74, 213) or Color3.fromRGB(35, 37, 51)
    end
    pages[name]()
end

for index, tabName in ipairs({"FARM", "REROLL", "REWARDS", "SETTINGS"}) do
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.25, -5, 1, 0)
    button.Position = UDim2.new((index - 1) * 0.25, (index - 1) * 5, 0, 0)
    button.BackgroundColor3 = Color3.fromRGB(35, 37, 51)
    button.Text = tabName
    button.TextColor3 = Color3.fromRGB(238, 238, 248)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 10
    button.Parent = tabBar
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)
    tabButtons[tabName] = button
    button.MouseButton1Click:Connect(function() switchTab(tabName) end)
end

-- Drag window by header.
do
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    table.insert(State.Connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end

close.MouseButton1Click:Connect(function()
    main.Visible = false
    setStatus("UI hidden; use script re-execution to reopen")
end)

-- Main loop: rate-limited, ordinary client movement only.
table.insert(State.Connections, RunService.Heartbeat:Connect(function()
    if not State.Running or not State.AutoFarm then return end
    if os.clock() - State.LastAction < State.ActionCooldown then return end
    State.LastAction = os.clock()

    local character = getCharacter()
    local humanoid = getHumanoid(character)
    local root = getRoot(character)
    if not character or not humanoid or humanoid.Health <= 0 or not root then
        setStatus("Waiting for character")
        return
    end

    if State.AutoEquip then equipFirstTool() end
    local target = findNearestTarget()
    if not target then
        setStatus("Searching for NPCs")
        return
    end

    State.TargetName = target.Name
    moveNearTarget(target)
    if State.AutoUseTool then useEquippedTool() end
    setStatus("Farming: " .. target.Name)
end))

if getgenv then
    getgenv().AnimeZeroKaitun_Stop = function()
        State.Running = false
        State.AutoFarm = false
        State.AutoUseTool = false
        safeDisconnectAll()
        if gui then pcall(function() gui:Destroy() end) end
    end
end

switchTab("FARM")
setStatus("Loaded — configure Farm tab")
