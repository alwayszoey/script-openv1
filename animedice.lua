--[[
    AxionHub AutoDice v11.1
    Hotfix: UI ไม่ขึ้น / blur ค้าง
--]]

local Services = {
    Players = game:GetService("Players"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    RunService = game:GetService("RunService"),
    TweenService = game:GetService("TweenService"),
    UserInputService = game:GetService("UserInputService"),
    Lighting = game:GetService("Lighting"),
}

local LP = Services.Players.LocalPlayer
local RS = Services.ReplicatedStorage
local Tween = Services.TweenService
local UIS = Services.UserInputService
local Lighting = Services.Lighting

local Config = {
    Name = "AxionHub_AutoDice",
    Version = "v11.1",
    Accent = Color3.fromRGB(168, 85, 247),
    AccentDim = Color3.fromRGB(124, 58, 237),
    AccentLight = Color3.fromRGB(222, 192, 255),
    BgTop = Color3.fromRGB(14, 4, 26),
    BgBot = Color3.fromRGB(0, 0, 0),
    CardTop = Color3.fromRGB(56, 22, 96),
    CardMid = Color3.fromRGB(34, 12, 64),
    CardBot = Color3.fromRGB(18, 6, 36),
    SidebarTop = Color3.fromRGB(62, 24, 108),
    SidebarBot = Color3.fromRGB(28, 10, 52),
    ToggleOff = Color3.fromRGB(22, 8, 42),
    ToggleOn = Color3.fromRGB(168, 85, 247),
    Text = Color3.fromRGB(248, 244, 255),
    TextDim = Color3.fromRGB(200, 180, 235),
    Muted = Color3.fromRGB(140, 118, 178),
    Good = Color3.fromRGB(130, 255, 180),
    Bad = Color3.fromRGB(255, 100, 130),
    Gold = Color3.fromRGB(255, 200, 80),
    Font = Enum.Font.Gotham,
    FontBold = Enum.Font.GothamBold,
    FontMedium = Enum.Font.GothamMedium,
}

local State = {
    page = "MAIN", mode = "AUTO", running = false, rolls = 0,
    autoRollOn = false, thread = nil, spamSpeed = 0.03,
    bypassAnim = true, killCutscene = true,
    autoCollect = false, collectThread = nil,
    collectRate = 0.5, plotMin = 1, plotMax = 16,
    collected = 0, lastPlot = 0, collectStarted = false,
    minimized = false,
}

local function getSafeParent()
    if type(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    return game:GetService("CoreGui")
end

local function safeFind(root, ...)
    local node = root
    for _, name in ipairs({...}) do
        if not node then return nil end
        local ok, child = pcall(function() return node:WaitForChild(name, 5) end)
        if not ok or not child then return nil end
        node = child
    end
    return node
end

local Remotes = {
    RollDice = safeFind(RS, "Network", "RollService", "RF", "RollDice"),
    SetAutoRoll = safeFind(RS, "Network", "RollService", "RE", "SetAutoRoll"),
    RollMessage = safeFind(RS, "Network", "RollService", "RE", "RollMessage"),
    CollectBalance = safeFind(RS, "Network", "PlotService", "RE", "CollectBalance"),
}

local remotesReady = Remotes.RollDice ~= nil and Remotes.SetAutoRoll ~= nil
local collectReady = Remotes.CollectBalance ~= nil

local antiFX = { camModel = nil, cutscene = nil, rollingDir = nil, ccEffects = {} }

local function initAntiFX()
    local rolling = safeFind(RS, "Framework", "Features", "Rolling")
    if rolling then
        antiFX.cutscene = rolling:FindFirstChild("RollCutscene")
        if antiFX.cutscene then
            antiFX.camModel = antiFX.cutscene:FindFirstChild("CameraModel")
        end
    end

    antiFX.ccEffects = {}
    for _, name in ipairs({
        "VFXImpactFrameWhite", "WhiteImpactFrame",
        "BlackImpactFrame", "VFXImpactFrameBlack"
    }) do
        local fx = Lighting:FindFirstChild(name)
        if fx and fx:IsA("PostEffect") then
            antiFX.ccEffects[#antiFX.ccEffects + 1] = fx
        end
    end

    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if pg then
        local root = pg:FindFirstChild("Root")
        if root then
            antiFX.rollingDir = root:FindFirstChild("Rolling")
        end
    end

    if antiFX.cutscene then
        local lines = antiFX.cutscene:FindFirstChild("lines")
        if lines then pcall(function() lines:Destroy() end) end
        for _, s in ipairs(antiFX.cutscene:GetChildren()) do
            if s:IsA("Sound") then
                pcall(function() s.Volume = 0; s:Stop() end)
            end
        end
    end
end

local function tickAntiFX()
    if not State.bypassAnim then return end
    if State.killCutscene and antiFX.camModel then
        pcall(function()
            antiFX.camModel.Transparency = 1
            antiFX.camModel.CanCollide = false
            antiFX.camModel.Anchored = true
            for _, p in ipairs(antiFX.camModel:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.Transparency = 1
                    p.CanCollide = false
                end
            end
        end)
    end
    for _, fx in ipairs(antiFX.ccEffects) do
        if fx.Parent and fx.Enabled then fx.Enabled = false end
    end
    if antiFX.rollingDir and antiFX.rollingDir.Parent then
        if antiFX.rollingDir.Visible then antiFX.rollingDir.Visible = false end
        for _, c in ipairs(antiFX.rollingDir:GetChildren()) do
            if c:IsA("GuiObject") and c.Visible then c.Visible = false end
        end
    end
end

initAntiFX()
task.spawn(function()
    while true do
        task.wait(2)
        initAntiFX()
    end
end)
Services.RunService.Heartbeat:Connect(tickAntiFX)

local function doRoll()
    if not Remotes.RollDice then return false end
    local ok = pcall(function() Remotes.RollDice:InvokeServer() end)
    if ok then State.rolls = State.rolls + 1 end
    if (State.mode == "AUTO" or State.mode == "BOTH")
        and not State.autoRollOn and Remotes.SetAutoRoll then
        pcall(function()
            Remotes.SetAutoRoll:FireServer(true)
            State.autoRollOn = true
        end)
    end
    return ok
end

local function diceLoop()
    State.running = true
    while State.running do
        if State.mode == "SPAM" or State.mode == "BOTH" then
            doRoll()
        elseif State.mode == "AUTO" then
            if not State.autoRollOn and Remotes.SetAutoRoll then
                pcall(function()
                    Remotes.SetAutoRoll:FireServer(true)
                    State.autoRollOn = true
                end)
            end
        end
        task.wait(State.spamSpeed)
    end
end

local function startDice()
    if State.running or not remotesReady then return end
    State.thread = task.spawn(diceLoop)
end

local function stopDice()
    State.running = false
    if State.thread then pcall(task.cancel, State.thread) end
    if State.autoRollOn and Remotes.SetAutoRoll then
        pcall(function() Remotes.SetAutoRoll:FireServer(false) end)
        State.autoRollOn = false
    end
end

if Remotes.RollMessage then
    Remotes.RollMessage.OnClientEvent:Connect(function() end)
end

local function collectOnePlot(plotNum)
    if not Remotes.CollectBalance then return end
    pcall(function() Remotes.CollectBalance:FireServer(plotNum) end)
    State.collected = State.collected + 1
    State.lastPlot = plotNum
end

local function collectLoop()
    while State.autoCollect do
        for plotNum = State.plotMin, State.plotMax do
            if not State.autoCollect then break end
            collectOnePlot(plotNum)
            task.wait(0.04)
        end
        task.wait(State.collectRate)
    end
end

local function startCollect()
    if State.collectThread or not collectReady then return end
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

LP.CharacterAdded:Connect(function()
    task.wait(2)
    if State.collectStarted and not State.autoCollect then
        startCollect()
    end
end)

local function buildUI()
    local parent = getSafeParent()
    local old = parent:FindFirstChild(Config.Name)
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = Config.Name
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999
    gui.Parent = parent

    local function corner(parent, r)
        local c = Instance.new("UICorner", parent)
        c.CornerRadius = UDim.new(0, r)
        return c
    end

    local function gradient(parent, rot, colors)
        local g = Instance.new("UIGradient", parent)
        g.Rotation = rot or 90
        if colors then
            g.Color = ColorSequence.new(colors)
        end
        return g
    end

    local function toggleGlow(parent)
        local hl = Instance.new("Frame", parent)
        hl.Size = UDim2.new(0.6, 0, 0.6, 0)
        hl.Position = UDim2.new(0, 0, 0, 0)
        hl.BackgroundColor3 = Color3.fromRGB(255, 240, 255)
        hl.BackgroundTransparency = 0.35
        hl.BorderSizePixel = 0
        hl.ZIndex = 2
        corner(hl, 999)
        local g = Instance.new("UIGradient", hl)
        g.Rotation = 135
        g.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0.0, 0.25),
            NumberSequenceKeypoint.new(0.6, 1.0),
            NumberSequenceKeypoint.new(1.0, 1.0),
        }
        return hl
    end

    local function label(parent, text, size, pos, font, ts, color, align)
        local l = Instance.new("TextLabel", parent)
        l.Text = text
        l.Size = size
        l.Position = pos
        l.Font = font or Config.Font
        l.TextSize = ts or 11
        l.TextColor3 = color or Config.Text
        l.BackgroundTransparency = 1
        l.TextXAlignment = align or Enum.TextXAlignment.Left
        l.ZIndex = 5
        return l
    end

    local function card(parent, size, pos)
        local c = Instance.new("Frame")
        c.Size = size
        c.Position = pos
        c.BackgroundColor3 = Config.CardMid
        c.BorderSizePixel = 0
        c.ZIndex = 3
        c.Parent = parent
        corner(c, 10)
        gradient(c, 90, {
            ColorSequenceKeypoint.new(0.00, Config.CardTop),
            ColorSequenceKeypoint.new(0.55, Config.CardMid),
            ColorSequenceKeypoint.new(1.00, Config.CardBot),
        })
        return c
    end

    local function makeToggle(parent, y, title, defaultOn, cb)
        local row = Instance.new("Frame", parent)
        row.Size = UDim2.new(1, 0, 0, 40)
        row.Position = UDim2.new(0, 0, 0, y)
        row.BackgroundTransparency = 1
        row.ZIndex = 4

        label(row, title, UDim2.new(0.75, 0, 1, 0), UDim2.new(0, 14, 0, 0),
            Config.FontMedium, 11.5, Config.Text)

        local pill = Instance.new("TextButton", row)
        pill.Size = UDim2.new(0, 46, 0, 24)
        pill.Position = UDim2.new(1, -60, 0.5, -12)
        pill.BackgroundColor3 = Color3.fromRGB(10, 3, 20)
        pill.Text = ""
        pill.AutoButtonColor = false
        pill.ZIndex = 5
        corner(pill, 999)

        local pillGrad = gradient(pill, 0)
        pillGrad.Color = defaultOn and ColorSequence.new(Config.ToggleOn, Config.AccentDim)
            or ColorSequence.new(Config.ToggleOff, Config.ToggleOff)

        toggleGlow(pill)

        local knob = Instance.new("Frame", pill)
        knob.Size = UDim2.new(0, 18, 0, 18)
        knob.Position = defaultOn and UDim2.new(1, -21, 0.5, -9)
            or UDim2.new(0, 3, 0.5, -9)
        knob.BackgroundColor3 = Color3.new(1, 1, 1)
        knob.BorderSizePixel = 0
        knob.ZIndex = 6
        corner(knob, 999)

        local on = defaultOn
        local function update()
            pillGrad.Color = on and ColorSequence.new(Config.ToggleOn, Config.AccentDim)
                or ColorSequence.new(Config.ToggleOff, Config.ToggleOff)
            Tween:Create(knob, TweenInfo.new(0.22), {
                Position = on and UDim2.new(1, -21, 0.5, -9)
                    or UDim2.new(0, 3, 0.5, -9)
            }):Play()
        end

        pill.MouseButton1Click:Connect(function()
            on = not on
            update()
            if cb then cb(on) end
        end)

        return { Set = function(v) on = v; update() end }
    end

    local miniBtn = Instance.new("TextButton")
    miniBtn.Name = "MiniBtn"
    miniBtn.Size = UDim2.new(0, 48, 0, 48)
    miniBtn.Position = UDim2.new(0, 20, 0, 100)
    miniBtn.BackgroundColor3 = Config.CardMid
    miniBtn.BorderSizePixel = 0
    miniBtn.Text = ""
    miniBtn.AutoButtonColor = false
    miniBtn.Visible = false
    miniBtn.Active = true
    miniBtn.Draggable = true
    miniBtn.Parent = gui
    corner(miniBtn, 12)
    gradient(miniBtn, 90, {Config.CardTop, Config.CardBot})
    label(miniBtn, "◆", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
        Config.FontBold, 22, Config.AccentLight, Enum.TextXAlignment.Center)

    local win = Instance.new("Frame")
    win.Name = "Window"
    win.Size = UDim2.new(0, 580, 0, 400)
    win.Position = UDim2.new(0.5, -290, 0.5, -200)
    win.BackgroundColor3 = Config.BgTop
    win.BackgroundTransparency = 0.15
    win.BorderSizePixel = 0
    win.Active = true
    win.ClipsDescendants = true
    win.Parent = gui
    corner(win, 16)
    gradient(win, 90, {Config.BgTop, Config.BgBot})

    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 155, 1, 0)
    sidebar.BackgroundColor3 = Config.SidebarTop
    sidebar.BorderSizePixel = 0
    sidebar.Parent = win
    corner(sidebar, 16)
    gradient(sidebar, 90, {Config.SidebarTop, Config.SidebarBot})

    local logoBox = Instance.new("Frame")
    logoBox.Size = UDim2.new(0, 44, 0, 44)
    logoBox.Position = UDim2.new(0, 18, 0, 18)
    logoBox.BackgroundColor3 = Config.CardMid
    logoBox.BorderSizePixel = 0
    logoBox.ZIndex = 3
    logoBox.Parent = sidebar
    corner(logoBox, 12)
    gradient(logoBox, 135, {Config.CardTop, Config.CardBot})
    label(logoBox, "◆", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
        Config.FontBold, 22, Config.AccentLight, Enum.TextXAlignment.Center)

    label(sidebar, "AxionHub", UDim2.new(1, -20, 0, 18), UDim2.new(0, 18, 0, 70),
        Config.FontBold, 15, Config.Text)

    label(sidebar, "AutoDice  " .. Config.Version,
        UDim2.new(1, -20, 0, 14), UDim2.new(0, 18, 0, 88),
        Config.Font, 10, Config.Muted)

    local pages = { "MAIN", "SETTINGS" }
    local pageIcons = { "🏠", "⚙" }
    local pageDesc = { MAIN = "dice & collect", SETTINGS = "animation / range" }
    local pageBtns = {}

    for i, p in ipairs(pages) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -24, 0, 44)
        btn.Position = UDim2.new(0, 12, 0, 132 + (i - 1) * 50)
        btn.BackgroundColor3 = Config.CardMid
        btn.BackgroundTransparency = 0.7
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.ZIndex = 3
        btn.Parent = sidebar
        corner(btn, 10)

        local glow = Instance.new("Frame", btn)
        glow.Size = UDim2.new(1, 0, 1, 0)
        glow.BackgroundColor3 = Config.Accent
        glow.BackgroundTransparency = 0.85
        glow.BorderSizePixel = 0
        glow.Visible = false
        glow.ZIndex = 1
        corner(glow, 10)

        local badge = Instance.new("Frame", btn)
        badge.Size = UDim2.new(0, 28, 0, 28)
        badge.Position = UDim2.new(0, 8, 0.5, -14)
        badge.BackgroundColor3 = Config.CardTop
        badge.BorderSizePixel = 0
        badge.ZIndex = 4
        corner(badge, 8)

        label(badge, pageIcons[i], UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
            Config.FontBold, 14, Config.AccentLight, Enum.TextXAlignment.Center)

        local nameLbl = label(btn, p:sub(1, 1) .. p:sub(2):lower(),
            UDim2.new(1, -50, 0, 14), UDim2.new(0, 44, 0, 7),
            Config.FontBold, 11.5, Config.TextDim)

        local descLbl = label(btn, pageDesc[p],
            UDim2.new(1, -50, 0, 12), UDim2.new(0, 44, 0, 23),
            Config.Font, 9, Config.Muted)

        pageBtns[p] = { btn = btn, glow = glow, name = nameLbl }
    end

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -155, 1, 0)
    content.Position = UDim2.new(0, 155, 0, 0)
    content.BackgroundTransparency = 1
    content.Parent = win

    local mainPage = Instance.new("Frame")
    mainPage.Size = UDim2.new(1, 0, 1, 0)
    mainPage.BackgroundTransparency = 1
    mainPage.Parent = content

    local header = card(mainPage, UDim2.new(1, -36, 0, 46), UDim2.new(0, 18, 0, 16))

    local dot = Instance.new("Frame", header)
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.Position = UDim2.new(0, 14, 0.5, -4)
    dot.BackgroundColor3 = Config.Muted
    dot.BorderSizePixel = 0
    dot.ZIndex = 5
    corner(dot, 999)

    local statusTxt = label(header, "READY",
        UDim2.new(1, -90, 1, 0), UDim2.new(0, 30, 0, 0),
        Config.Font, 11, Config.Text)

    task.spawn(function()
        while statusTxt.Parent do
            local ready = remotesReady
            local stat = ready and (State.running and "RUNNING" or "IDLE") or "NO REMOTES"
            local color = ready and (State.running and Config.Good or Config.Muted) or Config.Bad
            statusTxt.Text = string.format("💤 · %s · rolls: %d · 💰 %d",
                stat, State.rolls, State.collected)
            dot.BackgroundColor3 = color
            task.wait(0.2)
        end
    end)

    local modeCard = card(mainPage, UDim2.new(1, -36, 0, 106), UDim2.new(0, 18, 0, 76))

    label(modeCard, "MODE", UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 8),
        Config.FontBold, 9.5, Config.AccentLight)

    local modes = { "AUTO", "SPAM", "BOTH" }
    local modeBtns = {}

    for i, m in ipairs(modes) do
        local mb = Instance.new("TextButton")
        mb.Size = UDim2.new(0, 82, 0, 32)
        mb.Position = UDim2.new(0, 14 + (i - 1) * 88, 0, 28)
        mb.BackgroundColor3 = Color3.fromRGB(16, 4, 32)
        mb.BackgroundTransparency = 0.35
        mb.BorderSizePixel = 0
        mb.Text = m
        mb.Font = Config.FontBold
        mb.TextSize = 11
        mb.TextColor3 = Config.TextDim
        mb.AutoButtonColor = false
        mb.ZIndex = 4
        mb.Parent = modeCard
        corner(mb, 8)

        modeBtns[m] = mb

        mb.MouseButton1Click:Connect(function()
            State.mode = m
            for mm, btn in pairs(modeBtns) do
                local on = (mm == State.mode)
                btn.BackgroundColor3 = on and Config.Accent or Color3.fromRGB(16, 4, 32)
                btn.BackgroundTransparency = on and 0.2 or 0.35
                btn.TextColor3 = on and Config.Text or Config.TextDim
            end
        end)
    end

    for mm, btn in pairs(modeBtns) do
        local on = (mm == State.mode)
        btn.BackgroundColor3 = on and Config.Accent or Color3.fromRGB(16, 4, 32)
        btn.BackgroundTransparency = on and 0.2 or 0.35
        btn.TextColor3 = on and Config.Text or Config.TextDim
    end

    local autoRollRow = Instance.new("Frame", modeCard)
    autoRollRow.Size = UDim2.new(1, -28, 0, 40)
    autoRollRow.Position = UDim2.new(0, 14, 0, 66)
    autoRollRow.BackgroundTransparency = 1
    autoRollRow.ZIndex = 4

    label(autoRollRow, "🎲 Auto Roll",
        UDim2.new(0.7, 0, 1, 0), UDim2.new(0, 0, 0, 0),
        Config.FontBold, 12, Config.Text)

    local arPill = Instance.new("TextButton", autoRollRow)
    arPill.Size = UDim2.new(0, 62, 0, 30)
    arPill.Position = UDim2.new(1, -62, 0.5, -15)
    arPill.BackgroundColor3 = Color3.fromRGB(10, 3, 20)
    arPill.Text = ""
    arPill.AutoButtonColor = false
    arPill.ZIndex = 5
    corner(arPill, 999)

    local arGrad = gradient(arPill, 0, {Config.ToggleOff, Config.ToggleOff})
    toggleGlow(arPill)

    local arK = Instance.new("Frame", arPill)
    arK.Size = UDim2.new(0, 24, 0, 24)
    arK.Position = UDim2.new(0, 3, 0.5, -12)
    arK.BackgroundColor3 = Color3.new(1, 1, 1)
    arK.BorderSizePixel = 0
    arK.ZIndex = 6
    corner(arK, 999)

    arPill.MouseButton1Click:Connect(function()
        if State.running then stopDice() else startDice() end
        local on = State.running
        arGrad.Color = on and ColorSequence.new(Config.ToggleOn, Config.AccentDim)
            or ColorSequence.new(Config.ToggleOff, Config.ToggleOff)
        Tween:Create(arK, TweenInfo.new(0.25), {
            Position = on and UDim2.new(1, -27, 0.5, -12)
                or UDim2.new(0, 3, 0.5, -12),
        }):Play()
    end)

    local speedCard = card(mainPage, UDim2.new(1, -36, 0, 62), UDim2.new(0, 18, 0, 192))

    label(speedCard, "SPAM SPEED",
        UDim2.new(0.5, 0, 0, 14), UDim2.new(0, 12, 0, 8),
        Config.FontBold, 9.5, Config.AccentLight)

    local spdVal = label(speedCard, "33 / sec",
        UDim2.new(0.5, -12, 0, 14), UDim2.new(0.5, 0, 0, 8),
        Config.FontBold, 11, Config.Text, Enum.TextXAlignment.Right)

    local track = Instance.new("TextButton", speedCard)
    track.Size = UDim2.new(1, -24, 0, 10)
    track.Position = UDim2.new(0, 12, 0, 36)
    track.BackgroundColor3 = Color3.fromRGB(6, 2, 12)
    track.BorderSizePixel = 0
    track.Text = ""
    track.AutoButtonColor = false
    track.ZIndex = 4
    corner(track, 999)

    local fill = Instance.new("Frame", track)
    fill.Size = UDim2.new(0.5, 0, 1, 0)
    fill.BackgroundColor3 = Config.Accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 5
    corner(fill, 999)
    gradient(fill, 0, {Config.AccentDim, Config.AccentLight})

    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0.5, -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 6
    corner(knob, 999)

    local draggingSlider = false
    local function setFromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -7, 0.5, -7)
        local rate = math.floor(20 + rel * 180)
        State.spamSpeed = 1 / rate
        spdVal.Text = rate .. " / sec"
    end

    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = true
            setFromX(inp.Position.X)
        end
    end)
    track.InputChanged:Connect(function(inp)
        if draggingSlider and (inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
            setFromX(inp.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = false
        end
    end)

    local collectCard = card(mainPage, UDim2.new(1, -36, 0, 62), UDim2.new(0, 18, 0, 262))

    makeToggle(collectCard, 11, "💰 AFK Collect Money",
        State.autoCollect,
        function(v)
            if v then startCollect() else stopCollect() end
        end)

    label(collectCard, string.format("every %.1fs · plot %d→%d",
        State.collectRate, State.plotMin, State.plotMax),
        UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 42),
        Config.Font, 9, Config.AccentLight)

    local settingsPage = Instance.new("Frame")
    settingsPage.Size = UDim2.new(1, 0, 1, 0)
    settingsPage.BackgroundTransparency = 1
    settingsPage.Visible = false
    settingsPage.Parent = content

    local sHeader = card(settingsPage, UDim2.new(1, -36, 0, 46), UDim2.new(0, 18, 0, 16))
    label(sHeader, "⚙  Settings",
        UDim2.new(1, -30, 1, 0), UDim2.new(0, 16, 0, 0),
        Config.FontBold, 12, Config.Text)

    local setCard = card(settingsPage, UDim2.new(1, -36, 0, 92), UDim2.new(0, 18, 0, 76))

    makeToggle(setCard, 4, "Bypass Roll Animation",
        State.bypassAnim,
        function(v) State.bypassAnim = v end)

    makeToggle(setCard, 48, "Kill Camera Cutscene",
        State.killCutscene,
        function(v) State.killCutscene = v end)

    local rangeCard = card(settingsPage, UDim2.new(1, -36, 0, 76), UDim2.new(0, 18, 0, 180))

    label(rangeCard, "PLOT RANGE",
        UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 8),
        Config.FontBold, 9.5, Config.AccentLight)

    local rcVal = label(rangeCard, string.format("1 → %d", State.plotMax),
        UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 26),
        Config.Font, 10, Config.Text)

    local function rangeBtn(txt, xPos, val)
        local b = Instance.new("TextButton", rangeCard)
        b.Size = UDim2.new(0, 52, 0, 26)
        b.Position = UDim2.new(0, xPos, 0, 44)
        b.BackgroundColor3 = Config.CardTop
        b.BackgroundTransparency = 0.15
        b.Text = txt
        b.Font = Config.FontBold
        b.TextSize = 10
        b.TextColor3 = Config.Text
        b.AutoButtonColor = false
        b.ZIndex = 4
        b.Parent = rangeCard
        corner(b, 8)

        b.MouseButton1Click:Connect(function()
            State.plotMin, State.plotMax = 1, val
            rcVal.Text = string.format("1 → %d", State.plotMax)
        end)
    end

    rangeBtn("1 → 4", 14, 4)
    rangeBtn("1 → 8", 72, 8)
    rangeBtn("1 → 16", 130, 16)

    local function applyPage()
        for p, data in pairs(pageBtns) do
            local on = (p == State.page)
            data.glow.Visible = on
            data.name.TextColor3 = on and Config.Text or Config.TextDim
            data.btn.BackgroundTransparency = on and 0.15 or 0.7
        end
        mainPage.Visible = (State.page == "MAIN")
        settingsPage.Visible = (State.page == "SETTINGS")
    end

    for p, data in pairs(pageBtns) do
        data.btn.MouseButton1Click:Connect(function()
            State.page = p
            applyPage()
        end)
    end

    local topBtns = Instance.new("Frame")
    topBtns.Size = UDim2.new(0, 60, 0, 22)
    topBtns.Position = UDim2.new(1, -70, 0, 10)
    topBtns.BackgroundTransparency = 1
    topBtns.ZIndex = 10
    topBtns.Parent = win

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 22, 0, 22)
    minBtn.Position = UDim2.new(0, 0, 0, 0)
    minBtn.BackgroundColor3 = Config.CardTop
    minBtn.BackgroundTransparency = 0.3
    minBtn.BorderSizePixel = 0
    minBtn.Text = "—"
    minBtn.Font = Config.FontBold
    minBtn.TextSize = 14
    minBtn.TextColor3 = Config.Text
    minBtn.AutoButtonColor = false
    minBtn.ZIndex = 11
    minBtn.Parent = topBtns
    corner(minBtn, 999)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(0, 32, 0, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 20, 35)
    closeBtn.BackgroundTransparency = 0.15
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "✕"
    closeBtn.Font = Config.FontBold
    closeBtn.TextSize = 12
    closeBtn.TextColor3 = Config.Text
    closeBtn.AutoButtonColor = false
    closeBtn.ZIndex = 11
    closeBtn.Parent = topBtns
    corner(closeBtn, 999)

    local blur = Instance.new("BlurEffect")
    blur.Name = "AxionHubBlur_Internal"
    blur.Size = 8
    blur.Parent = Lighting

    minBtn.MouseButton1Click:Connect(function()
        State.minimized = true
        win.Visible = false
        miniBtn.Visible = true
        blur.Size = 0
    end)

    closeBtn.MouseButton1Click:Connect(function()
        pcall(stopDice)
        pcall(stopCollect)
        pcall(function() blur:Destroy() end)
        pcall(function() gui:Destroy() end)
    end)

    miniBtn.MouseButton1Click:Connect(function()
        State.minimized = false
        win.Visible = true
        miniBtn.Visible = false
        blur.Size = 8
    end)

    gui.Destroying:Connect(function()
        pcall(function() blur:Destroy() end)
    end)

    local draggingWin = false
    local dragStart, startPos
    header.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            draggingWin = true
            dragStart = inp.Position
            startPos = win.Position
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if draggingWin and (inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - dragStart
            win.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            draggingWin = false
        end
    end)

    applyPage()
    return gui
end

local ok, err = pcall(buildUI)
if not ok then
    warn("[AxionHub] buildUI ERROR:", err)
    pcall(function()
        local b = Lighting:FindFirstChild("AxionHubBlur_Internal")
        if b then b:Destroy() end
    end)
end

print("[AxionHub] " .. Config.Version .. " ready.")
