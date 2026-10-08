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
local RunService = Services.RunService

local Config = {
    Name = "AxionHub_AutoDice",
    Version = "v12",

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

    Font = Enum.Font.Gotham,
    FontBold = Enum.Font.GothamBold,
    FontMedium = Enum.Font.GothamMedium,

    BlurSize = 8,
}

local State = {
    Page = "MAIN",
    Mode = "AUTO",
    Running = false,
    Rolls = 0,
    AutoRollOn = false,
    DiceThread = nil,
    SpamSpeed = 0.03,
    BypassAnim = true,
    KillCutscene = true,

    AutoCollect = false,
    CollectThread = nil,
    CollectRate = 0.5,
    PlotMin = 1,
    PlotMax = 16,
    Collected = 0,
    LastPlot = 0,
    CollectStarted = false,

    Minimized = false,
}

local function SafeParent()
    if type(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    return game:GetService("CoreGui")
end

local function SafeFind(root, ...)
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
    RollDice = SafeFind(RS, "Network", "RollService", "RF", "RollDice"),
    SetAutoRoll = SafeFind(RS, "Network", "RollService", "RE", "SetAutoRoll"),
    RollMessage = SafeFind(RS, "Network", "RollService", "RE", "RollMessage"),
    CollectBalance = SafeFind(RS, "Network", "PlotService", "RE", "CollectBalance"),
}

local RemotesReady = Remotes.RollDice ~= nil and Remotes.SetAutoRoll ~= nil
local CollectReady = Remotes.CollectBalance ~= nil

local AntiFX = { CamModel = nil, Cutscene = nil, RollingDir = nil, CCEffects = {} }

local function InitAntiFX()
    local rolling = SafeFind(RS, "Framework", "Features", "Rolling")
    if rolling then
        AntiFX.Cutscene = rolling:FindFirstChild("RollCutscene")
        if AntiFX.Cutscene then
            AntiFX.CamModel = AntiFX.Cutscene:FindFirstChild("CameraModel")
        end
    end

    AntiFX.CCEffects = {}
    for _, name in ipairs({
        "VFXImpactFrameWhite", "WhiteImpactFrame",
        "BlackImpactFrame", "VFXImpactFrameBlack",
    }) do
        local fx = Lighting:FindFirstChild(name)
        if fx and fx:IsA("PostEffect") then
            table.insert(AntiFX.CCEffects, fx)
        end
    end

    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if pg then
        local root = pg:FindFirstChild("Root")
        if root then
            AntiFX.RollingDir = root:FindFirstChild("Rolling")
        end
    end

    if AntiFX.Cutscene then
        local lines = AntiFX.Cutscene:FindFirstChild("lines")
        if lines then pcall(function() lines:Destroy() end) end
        for _, s in ipairs(AntiFX.Cutscene:GetChildren()) do
            if s:IsA("Sound") then
                pcall(function()
                    s.Volume = 0
                    s:Stop()
                end)
            end
        end
    end
end

local function TickAntiFX()
    if not State.BypassAnim then return end

    if State.KillCutscene and AntiFX.CamModel then
        pcall(function()
            AntiFX.CamModel.Transparency = 1
            AntiFX.CamModel.CanCollide = false
            AntiFX.CamModel.Anchored = true
            for _, p in ipairs(AntiFX.CamModel:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.Transparency = 1
                    p.CanCollide = false
                end
            end
        end)
    end

    for _, fx in ipairs(AntiFX.CCEffects) do
        if fx.Parent and fx.Enabled then fx.Enabled = false end
    end

    if AntiFX.RollingDir and AntiFX.RollingDir.Parent then
        if AntiFX.RollingDir.Visible then AntiFX.RollingDir.Visible = false end
        for _, c in ipairs(AntiFX.RollingDir:GetChildren()) do
            if c:IsA("GuiObject") and c.Visible then c.Visible = false end
        end
    end
end

InitAntiFX()
task.spawn(function()
    while true do
        task.wait(2)
        InitAntiFX()
    end
end)
RunService.Heartbeat:Connect(TickAntiFX)

local function DoRoll()
    if not Remotes.RollDice then return end
    local ok = pcall(function() Remotes.RollDice:InvokeServer() end)
    if ok then State.Rolls = State.Rolls + 1 end

    if (State.Mode == "AUTO" or State.Mode == "BOTH")
        and not State.AutoRollOn and Remotes.SetAutoRoll then
        pcall(function()
            Remotes.SetAutoRoll:FireServer(true)
            State.AutoRollOn = true
        end)
    end
end

local function DiceLoop()
    State.Running = true
    while State.Running do
        if State.Mode == "SPAM" or State.Mode == "BOTH" then
            DoRoll()
        elseif State.Mode == "AUTO" then
            if not State.AutoRollOn and Remotes.SetAutoRoll then
                pcall(function()
                    Remotes.SetAutoRoll:FireServer(true)
                    State.AutoRollOn = true
                end)
            end
        end
        task.wait(State.SpamSpeed)
    end
end

local function StartDice()
    if State.Running or not RemotesReady then return end
    State.DiceThread = task.spawn(DiceLoop)
end

local function StopDice()
    State.Running = false
    if State.DiceThread then pcall(task.cancel, State.DiceThread) end
    if State.AutoRollOn and Remotes.SetAutoRoll then
        pcall(function() Remotes.SetAutoRoll:FireServer(false) end)
        State.AutoRollOn = false
    end
end

if Remotes.RollMessage then
    Remotes.RollMessage.OnClientEvent:Connect(function() end)
end

local function CollectOnePlot(plotNum)
    if not Remotes.CollectBalance then return end
    pcall(function() Remotes.CollectBalance:FireServer(plotNum) end)
    State.Collected = State.Collected + 1
    State.LastPlot = plotNum
end

local function CollectLoop()
    while State.AutoCollect do
        for plotNum = State.PlotMin, State.PlotMax do
            if not State.AutoCollect then break end
            CollectOnePlot(plotNum)
            task.wait(0.04)
        end
        task.wait(State.CollectRate)
    end
end

local function StartCollect()
    if State.CollectThread or not CollectReady then return end
    State.AutoCollect = true
    State.CollectStarted = true
    State.CollectThread = task.spawn(CollectLoop)
end

local function StopCollect()
    State.AutoCollect = false
    State.CollectStarted = false
    if State.CollectThread then
        pcall(task.cancel, State.CollectThread)
        State.CollectThread = nil
    end
end

LP.CharacterAdded:Connect(function()
    task.wait(2)
    if State.CollectStarted and not State.AutoCollect then
        StartCollect()
    end
end)

local function CreateCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function CreateGradient(parent, rotation, colorSeq, transpSeq)
    local g = Instance.new("UIGradient")
    g.Rotation = rotation or 90
    if colorSeq then g.Color = colorSeq end
    if transpSeq then g.Transparency = transpSeq end
    g.Parent = parent
    return g
end

local function MakeToggleGlow(parent)
    local hl = Instance.new("Frame")
    hl.Size = UDim2.new(0.6, 0, 0.6, 0)
    hl.Position = UDim2.new(0, 0, 0, 0)
    hl.BackgroundColor3 = Color3.fromRGB(255, 240, 255)
    hl.BackgroundTransparency = 0.35
    hl.BorderSizePixel = 0
    hl.ZIndex = 2
    hl.Parent = parent
    CreateCorner(hl, 999)

    local g = Instance.new("UIGradient", hl)
    g.Rotation = 135
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, 0.25),
        NumberSequenceKeypoint.new(0.6, 1.0),
        NumberSequenceKeypoint.new(1.0, 1.0),
    })
    g.Parent = hl
end

local function MakeLabel(parent, text, size, pos, font, textSize, color, align)
    local l = Instance.new("TextLabel")
    l.Text = text
    l.Size = size
    l.Position = pos
    l.Font = font or Config.Font
    l.TextSize = textSize or 11
    l.TextColor3 = color or Config.Text
    l.BackgroundTransparency = 1
    l.TextXAlignment = align or Enum.TextXAlignment.Left
    l.ZIndex = 5
    l.Parent = parent
    return l
end

local function MakeCard(parent, size, pos)
    local c = Instance.new("Frame")
    c.Size = size
    c.Position = pos
    c.BackgroundColor3 = Config.CardMid
    c.BorderSizePixel = 0
    c.ZIndex = 3
    c.Parent = parent
    CreateCorner(c, 10)

    local g = Instance.new("UIGradient", c)
    g.Rotation = 90
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Config.CardTop),
        ColorSequenceKeypoint.new(0.55, Config.CardMid),
        ColorSequenceKeypoint.new(1.00, Config.CardBot),
    })
    g.Parent = c
    return c
end

local function MakeToggle(parent, y, title, defaultOn, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 40)
    row.Position = UDim2.new(0, 0, 0, y)
    row.BackgroundTransparency = 1
    row.ZIndex = 4
    row.Parent = parent

    MakeLabel(row, title, UDim2.new(0.75, 0, 1, 0), UDim2.new(0, 14, 0, 0),
        Config.FontMedium, 11.5, Config.Text)

    local pill = Instance.new("TextButton")
    pill.Size = UDim2.new(0, 46, 0, 24)
    pill.Position = UDim2.new(1, -60, 0.5, -12)
    pill.BackgroundColor3 = Color3.fromRGB(10, 3, 20)
    pill.Text = ""
    pill.AutoButtonColor = false
    pill.ZIndex = 5
    pill.Parent = row
    CreateCorner(pill, 999)

    local pillGrad = Instance.new("UIGradient", pill)
    pillGrad.Rotation = 0
    pillGrad.Color = defaultOn
        and ColorSequence.new(Config.ToggleOn, Config.AccentDim)
        or ColorSequence.new(Config.ToggleOff, Config.ToggleOff)
    pillGrad.Parent = pill

    MakeToggleGlow(pill)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = defaultOn
        and UDim2.new(1, -21, 0.5, -9)
        or UDim2.new(0, 3, 0.5, -9)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 6
    knob.Parent = pill
    CreateCorner(knob, 999)

    local on = defaultOn
    local function Update()
        pillGrad.Color = on
            and ColorSequence.new(Config.ToggleOn, Config.AccentDim)
            or ColorSequence.new(Config.ToggleOff, Config.ToggleOff)
        Tween:Create(knob, TweenInfo.new(0.22), {
            Position = on
                and UDim2.new(1, -21, 0.5, -9)
                or UDim2.new(0, 3, 0.5, -9),
        }):Play()
    end

    pill.MouseButton1Click:Connect(function()
        on = not on
        Update()
        if callback then callback(on) end
    end)

    return {
        Set = function(v)
            on = v
            Update()
        end,
    }
end

local function BuildUI()
    local parent = SafeParent()
    local old = parent:FindFirstChild(Config.Name)
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = Config.Name
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999
    gui.Parent = parent

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
    CreateCorner(miniBtn, 12)

    local miniGrad = Instance.new("UIGradient", miniBtn)
    miniGrad.Rotation = 90
    miniGrad.Color = ColorSequence.new(Config.CardTop, Config.CardBot)
    miniGrad.Parent = miniBtn

    MakeLabel(miniBtn, "◆", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
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
    CreateCorner(win, 16)

    local winGrad = Instance.new("UIGradient", win)
    winGrad.Rotation = 90
    winGrad.Color = ColorSequence.new(Config.BgTop, Config.BgBot)
    winGrad.Parent = win

    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 155, 1, 0)
    sidebar.BackgroundColor3 = Config.SidebarTop
    sidebar.BorderSizePixel = 0
    sidebar.Parent = win
    CreateCorner(sidebar, 16)

    local sbGrad = Instance.new("UIGradient", sidebar)
    sbGrad.Rotation = 90
    sbGrad.Color = ColorSequence.new(Config.SidebarTop, Config.SidebarBot)
    sbGrad.Parent = sidebar

    local logoBox = Instance.new("Frame")
    logoBox.Size = UDim2.new(0, 44, 0, 44)
    logoBox.Position = UDim2.new(0, 18, 0, 18)
    logoBox.BackgroundColor3 = Config.CardMid
    logoBox.BorderSizePixel = 0
    logoBox.ZIndex = 3
    logoBox.Parent = sidebar
    CreateCorner(logoBox, 12)

    local lbGrad = Instance.new("UIGradient", logoBox)
    lbGrad.Rotation = 135
    lbGrad.Color = ColorSequence.new(Config.CardTop, Config.CardBot)
    lbGrad.Parent = logoBox

    MakeLabel(logoBox, "◆", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
        Config.FontBold, 22, Config.AccentLight, Enum.TextXAlignment.Center)

    MakeLabel(sidebar, "AxionHub",
        UDim2.new(1, -20, 0, 18), UDim2.new(0, 18, 0, 70),
        Config.FontBold, 15, Config.Text)

    MakeLabel(sidebar, "AutoDice  " .. Config.Version,
        UDim2.new(1, -20, 0, 14), UDim2.new(0, 18, 0, 88),
        Config.Font, 10, Config.Muted)

    local pages = {
        { Id = "MAIN", Icon = "🏠", Label = "Main", Desc = "dice & collect" },
        { Id = "SETTINGS", Icon = "⚙", Label = "Settings", Desc = "animation / range" },
    }

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
        CreateCorner(btn, 10)

        local glow = Instance.new("Frame")
        glow.Size = UDim2.new(1, 0, 1, 0)
        glow.BackgroundColor3 = Config.Accent
        glow.BackgroundTransparency = 0.85
        glow.BorderSizePixel = 0
        glow.Visible = false
        glow.ZIndex = 1
        glow.Parent = btn
        CreateCorner(glow, 10)

        local badge = Instance.new("Frame")
        badge.Size = UDim2.new(0, 28, 0, 28)
        badge.Position = UDim2.new(0, 8, 0.5, -14)
        badge.BackgroundColor3 = Config.CardTop
        badge.BorderSizePixel = 0
        badge.ZIndex = 4
        badge.Parent = btn
        CreateCorner(badge, 8)

        MakeLabel(badge, p.Icon, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
            Config.FontBold, 14, Config.AccentLight, Enum.TextXAlignment.Center)

        local nameLbl = MakeLabel(btn, p.Label,
            UDim2.new(1, -50, 0, 14), UDim2.new(0, 44, 0, 7),
            Config.FontBold, 11.5, Config.TextDim)

        MakeLabel(btn, p.Desc,
            UDim2.new(1, -50, 0, 12), UDim2.new(0, 44, 0, 23),
            Config.Font, 9, Config.Muted)

        pageBtns[p.Id] = {
            Btn = btn,
            Glow = glow,
            Name = nameLbl,
        }
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

    local header = MakeCard(mainPage, UDim2.new(1, -36, 0, 46), UDim2.new(0, 18, 0, 16))

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.Position = UDim2.new(0, 14, 0.5, -4)
    dot.BackgroundColor3 = Config.Muted
    dot.BorderSizePixel = 0
    dot.ZIndex = 5
    dot.Parent = header
    CreateCorner(dot, 999)

    local statusTxt = MakeLabel(header, "READY",
        UDim2.new(1, -90, 1, 0), UDim2.new(0, 30, 0, 0),
        Config.Font, 11, Config.Text)

    task.spawn(function()
        while statusTxt.Parent do
            local stat = RemotesReady
                and (State.Running and "RUNNING" or "IDLE")
                or "NO REMOTES"
            local color = RemotesReady
                and (State.Running and Config.Good or Config.Muted)
                or Config.Bad

            statusTxt.Text = string.format(
                "💤 · %s · rolls: %d · 💰 %d",
                stat, State.Rolls, State.Collected
            )
            dot.BackgroundColor3 = color
            task.wait(0.2)
        end
    end)

    local modeCard = MakeCard(mainPage, UDim2.new(1, -36, 0, 106), UDim2.new(0, 18, 0, 76))

    MakeLabel(modeCard, "MODE",
        UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 8),
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
        CreateCorner(mb, 8)

        modeBtns[m] = mb

        mb.MouseButton1Click:Connect(function()
            State.Mode = m
            for key, btn in pairs(modeBtns) do
                local on = (key == State.Mode)
                btn.BackgroundColor3 = on and Config.Accent or Color3.fromRGB(16, 4, 32)
                btn.BackgroundTransparency = on and 0.2 or 0.35
                btn.TextColor3 = on and Config.Text or Config.TextDim
            end
        end)
    end

    for key, btn in pairs(modeBtns) do
        local on = (key == State.Mode)
        btn.BackgroundColor3 = on and Config.Accent or Color3.fromRGB(16, 4, 32)
        btn.BackgroundTransparency = on and 0.2 or 0.35
        btn.TextColor3 = on and Config.Text or Config.TextDim
    end

    local autoRollRow = Instance.new("Frame")
    autoRollRow.Size = UDim2.new(1, -28, 0, 40)
    autoRollRow.Position = UDim2.new(0, 14, 0, 66)
    autoRollRow.BackgroundTransparency = 1
    autoRollRow.ZIndex = 4
    autoRollRow.Parent = modeCard

    MakeLabel(autoRollRow, "🎲 Auto Roll",
        UDim2.new(0.7, 0, 1, 0), UDim2.new(0, 0, 0, 0),
        Config.FontBold, 12, Config.Text)

    local arPill = Instance.new("TextButton")
    arPill.Size = UDim2.new(0, 62, 0, 30)
    arPill.Position = UDim2.new(1, -62, 0.5, -15)
    arPill.BackgroundColor3 = Color3.fromRGB(10, 3, 20)
    arPill.Text = ""
    arPill.AutoButtonColor = false
    arPill.ZIndex = 5
    arPill.Parent = autoRollRow
    CreateCorner(arPill, 999)

    local arGrad = Instance.new("UIGradient", arPill)
    arGrad.Rotation = 0
    arGrad.Color = ColorSequence.new(Config.ToggleOff, Config.ToggleOff)
    arGrad.Parent = arPill

    MakeToggleGlow(arPill)

    local arK = Instance.new("Frame")
    arK.Size = UDim2.new(0, 24, 0, 24)
    arK.Position = UDim2.new(0, 3, 0.5, -12)
    arK.BackgroundColor3 = Color3.new(1, 1, 1)
    arK.BorderSizePixel = 0
    arK.ZIndex = 6
    arK.Parent = arPill
    CreateCorner(arK, 999)

    arPill.MouseButton1Click:Connect(function()
        if State.Running then
            StopDice()
        else
            StartDice()
        end
        local on = State.Running
        arGrad.Color = on
            and ColorSequence.new(Config.ToggleOn, Config.AccentDim)
            or ColorSequence.new(Config.ToggleOff, Config.ToggleOff)
        Tween:Create(arK, TweenInfo.new(0.25), {
            Position = on
                and UDim2.new(1, -27, 0.5, -12)
                or UDim2.new(0, 3, 0.5, -12),
        }):Play()
    end)

    local speedCard = MakeCard(mainPage, UDim2.new(1, -36, 0, 62), UDim2.new(0, 18, 0, 192))

    MakeLabel(speedCard, "SPAM SPEED",
        UDim2.new(0.5, 0, 0, 14), UDim2.new(0, 12, 0, 8),
        Config.FontBold, 9.5, Config.AccentLight)

    local spdVal = MakeLabel(speedCard, "33 / sec",
        UDim2.new(0.5, -12, 0, 14), UDim2.new(0.5, 0, 0, 8),
        Config.FontBold, 11, Config.Text, Enum.TextXAlignment.Right)

    local track = Instance.new("TextButton")
    track.Size = UDim2.new(1, -24, 0, 10)
    track.Position = UDim2.new(0, 12, 0, 36)
    track.BackgroundColor3 = Color3.fromRGB(6, 2, 12)
    track.BorderSizePixel = 0
    track.Text = ""
    track.AutoButtonColor = false
    track.ZIndex = 4
    track.Parent = speedCard
    CreateCorner(track, 999)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0.5, 0, 1, 0)
    fill.BackgroundColor3 = Config.Accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 5
    fill.Parent = track
    CreateCorner(fill, 999)

    local fillGrad = Instance.new("UIGradient", fill)
    fillGrad.Rotation = 0
    fillGrad.Color = ColorSequence.new(Config.AccentDim, Config.AccentLight)
    fillGrad.Parent = fill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0.5, -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 6
    knob.Parent = track
    CreateCorner(knob, 999)

    local draggingSlider = false

    local function SetFromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -7, 0.5, -7)
        local rate = math.floor(20 + rel * 180)
        State.SpamSpeed = 1 / rate
        spdVal.Text = rate .. " / sec"
    end

    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = true
            SetFromX(inp.Position.X)
        end
    end)

    track.InputChanged:Connect(function(inp)
        if draggingSlider and (inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
            SetFromX(inp.Position.X)
        end
    end)

    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = false
        end
    end)

    local collectCard = MakeCard(mainPage, UDim2.new(1, -36, 0, 62), UDim2.new(0, 18, 0, 262))

    MakeToggle(collectCard, 11, "💰 AFK Collect Money", State.AutoCollect,
        function(v)
            if v then StartCollect() else StopCollect() end
        end)

    MakeLabel(collectCard,
        string.format("every %.1fs · plot %d→%d",
            State.CollectRate, State.PlotMin, State.PlotMax),
        UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 42),
        Config.Font, 9, Config.AccentLight)

    local settingsPage = Instance.new("Frame")
    settingsPage.Size = UDim2.new(1, 0, 1, 0)
    settingsPage.BackgroundTransparency = 1
    settingsPage.Visible = false
    settingsPage.Parent = content

    local sHeader = MakeCard(settingsPage, UDim2.new(1, -36, 0, 46), UDim2.new(0, 18, 0, 16))

    MakeLabel(sHeader, "⚙  Settings",
        UDim2.new(1, -30, 1, 0), UDim2.new(0, 16, 0, 0),
        Config.FontBold, 12, Config.Text)

    local setCard = MakeCard(settingsPage, UDim2.new(1, -36, 0, 92), UDim2.new(0, 18, 0, 76))

    MakeToggle(setCard, 4, "Bypass Roll Animation", State.BypassAnim,
        function(v) State.BypassAnim = v end)

    MakeToggle(setCard, 48, "Kill Camera Cutscene", State.KillCutscene,
        function(v) State.KillCutscene = v end)

    local rangeCard = MakeCard(settingsPage, UDim2.new(1, -36, 0, 76), UDim2.new(0, 18, 0, 180))

    MakeLabel(rangeCard, "PLOT RANGE",
        UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 8),
        Config.FontBold, 9.5, Config.AccentLight)

    local rcVal = MakeLabel(rangeCard,
        string.format("1 → %d", State.PlotMax),
        UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 26),
        Config.Font, 10, Config.Text)

    local function RangeBtn(txt, xPos, val)
        local b = Instance.new("TextButton")
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
        CreateCorner(b, 8)

        b.MouseButton1Click:Connect(function()
            State.PlotMin = 1
            State.PlotMax = val
            rcVal.Text = string.format("1 → %d", State.PlotMax)
        end)
    end

    RangeBtn("1 → 4", 14, 4)
    RangeBtn("1 → 8", 72, 8)
    RangeBtn("1 → 16", 130, 16)

    local function ApplyPage()
        for id, data in pairs(pageBtns) do
            local on = (id == State.Page)
            data.Glow.Visible = on
            data.Name.TextColor3 = on and Config.Text or Config.TextDim
            data.Btn.BackgroundTransparency = on and 0.15 or 0.7
        end
        mainPage.Visible = (State.Page == "MAIN")
        settingsPage.Visible = (State.Page == "SETTINGS")
    end

    for id, data in pairs(pageBtns) do
        data.Btn.MouseButton1Click:Connect(function()
            State.Page = id
            ApplyPage()
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
    CreateCorner(minBtn, 999)

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
    CreateCorner(closeBtn, 999)

    local blur = Instance.new("BlurEffect")
    blur.Name = "AxionHubBlur_Internal"
    blur.Size = Config.BlurSize
    blur.Parent = Lighting

    gui.Destroying:Connect(function()
        pcall(function() blur:Destroy() end)
    end)

    minBtn.MouseButton1Click:Connect(function()
        State.Minimized = true
        win.Visible = false
        miniBtn.Visible = true
        blur.Size = 0
    end)

    closeBtn.MouseButton1Click:Connect(function()
        pcall(StopDice)
        pcall(StopCollect)
        pcall(function() blur:Destroy() end)
        pcall(function() gui:Destroy() end)
    end)

    miniBtn.MouseButton1Click:Connect(function()
        State.Minimized = false
        win.Visible = true
        miniBtn.Visible = false
        blur.Size = Config.BlurSize
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

    ApplyPage()
    return gui
end

local ok, err = pcall(BuildUI)
if not ok then
    warn("[AxionHub] BuildUI Error: " .. tostring(err))
    pcall(function()
        local b = Lighting:FindFirstChild("AxionHubBlur_Internal")
        if b then b:Destroy() end
    end)
end
