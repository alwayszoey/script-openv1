--[[
    AxionHub AnimeDice  v1.0.3
    Neon Purple Gradient UI
    Glassmorphism Sidebar + Bright Controls
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
local RunService = Services.RunService

--=====================================================================
-- CONFIG
--=====================================================================
local Config = {
    Name = "AxionHub_AutoDice",
    Version = "v1.0.3",

    -- Neon Purple Gradient Palette (brighter)
    NeonBright = Color3.fromRGB(192, 132, 252),
    NeonDeep = Color3.fromRGB(147, 51, 234),
    NeonGlow = Color3.fromRGB(233, 213, 255),
    NeonAccent = Color3.fromRGB(168, 85, 247),
    NeonHot = Color3.fromRGB(217, 70, 239),

    -- Backgrounds (semi-transparent)
    BgDark = Color3.fromRGB(15, 10, 21),
    BgTop = Color3.fromRGB(48, 22, 78),       -- lighter purple tint (top)
    BgBot = Color3.fromRGB(12, 4, 22),        -- deep purple (bottom)
    BgCard = Color3.fromRGB(28, 14, 46),
    BgCardHi = Color3.fromRGB(42, 20, 68),
    BgSidebar = Color3.fromRGB(28, 14, 44),

    -- Window opacity
    WindowTransparency = 0.15,
    SidebarTransparency = 0.35,
    ContentTransparency = 0.1,
    CardTransparency = 0.15,

    -- Component colors (brighter)
    TrackBg = Color3.fromRGB(22, 10, 40),
    TrackBorder = Color3.fromRGB(120, 60, 200),
    PillOff = Color3.fromRGB(40, 20, 66),
    PillOffBorder = Color3.fromRGB(90, 45, 150),
    BtnInactive = Color3.fromRGB(52, 26, 84),
    BtnInactiveBorder = Color3.fromRGB(120, 60, 190),

    -- Text
    Text = Color3.fromRGB(248, 244, 255),
    TextDim = Color3.fromRGB(210, 190, 240),
    Muted = Color3.fromRGB(150, 128, 190),
    Good = Color3.fromRGB(130, 255, 180),
    Bad = Color3.fromRGB(255, 100, 130),

    Font = Enum.Font.Gotham,
    FontBold = Enum.Font.GothamBold,
    FontMedium = Enum.Font.GothamMedium,

    BlurSize = 10,
}

--=====================================================================
-- STATE
--=====================================================================
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

--=====================================================================
-- HELPERS
--=====================================================================
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

--=====================================================================
-- REMOTES
--=====================================================================
local Remotes = {
    RollDice = SafeFind(RS, "Network", "RollService", "RF", "RollDice"),
    SetAutoRoll = SafeFind(RS, "Network", "RollService", "RE", "SetAutoRoll"),
    RollMessage = SafeFind(RS, "Network", "RollService", "RE", "RollMessage"),
    CollectBalance = SafeFind(RS, "Network", "PlotService", "RE", "CollectBalance"),
}

local RemotesReady = Remotes.RollDice ~= nil and Remotes.SetAutoRoll ~= nil
local CollectReady = Remotes.CollectBalance ~= nil

--=====================================================================
-- ANTI-FX
--=====================================================================
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

--=====================================================================
-- DICE LOGIC
--=====================================================================
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

--=====================================================================
-- COLLECT LOGIC
--=====================================================================
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

--=====================================================================
-- UI HELPERS
--=====================================================================
local function Corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function Gradient(parent, rot, colors)
    local g = Instance.new("UIGradient")
    g.Rotation = rot or 90
    if colors then g.Color = colors end
    g.Parent = parent
    return g
end

local function Stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(120, 60, 200)
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0.4
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function Label(parent, text, size, pos, font, ts, color, align)
    local l = Instance.new("TextLabel")
    l.Text = text
    l.Size = size
    l.Position = pos
    l.Font = font or Config.Font
    l.TextSize = ts or 11
    l.TextColor3 = color or Config.Text
    l.BackgroundTransparency = 1
    l.TextXAlignment = align or Enum.TextXAlignment.Left
    l.ZIndex = 5
    l.Parent = parent
    return l
end

local function AccentBar(parent, height)
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 1, -16)
    bar.Position = UDim2.new(0, 8, 0, 8)
    bar.BackgroundColor3 = Config.NeonBright
    bar.BorderSizePixel = 0
    bar.ZIndex = 4
    bar.Parent = parent
    Corner(bar, 2)
    Gradient(bar, 90, ColorSequence.new(Config.NeonGlow, Config.NeonDeep))
    return bar
end

--=====================================================================
-- CARD
--=====================================================================
local function Card(parent, size, pos)
    local c = Instance.new("Frame")
    c.Size = size
    c.Position = pos
    c.BackgroundColor3 = Config.BgCard
    c.BackgroundTransparency = Config.CardTransparency
    c.BorderSizePixel = 0
    c.ZIndex = 3
    c.Parent = parent
    Corner(c, 10)

    Gradient(c, 90, ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Config.BgCardHi),
        ColorSequenceKeypoint.new(1.00, Config.BgCard),
    }))

    Stroke(c, Color3.fromRGB(80, 40, 130), 1, 0.35)

    return c
end

--=====================================================================
-- TOGGLE (Pill) — BRIGHT
--=====================================================================
local function Toggle(parent, y, title, defaultOn, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 44)
    row.Position = UDim2.new(0, 0, 0, y)
    row.BackgroundTransparency = 1
    row.ZIndex = 4
    row.Parent = parent

    Label(row, title, UDim2.new(0.75, 0, 1, 0), UDim2.new(0, 14, 0, 0),
        Config.FontMedium, 11.5, Config.Text)

    local pill = Instance.new("TextButton")
    pill.Size = UDim2.new(0, 48, 0, 26)
    pill.Position = UDim2.new(1, -62, 0.5, -13)
    pill.BackgroundColor3 = Config.PillOff
    pill.Text = ""
    pill.AutoButtonColor = false
    pill.ZIndex = 5
    pill.Parent = row
    Corner(pill, 999)

    -- Gradient
    local pillGrad = Instance.new("UIGradient", pill)
    pillGrad.Rotation = 0
    pillGrad.Color = defaultOn
        and ColorSequence.new(Config.NeonBright, Config.NeonDeep)
        or ColorSequence.new(Config.PillOff, Color3.fromRGB(30, 14, 52))
    pillGrad.Parent = pill

    -- Outline (brighter, thicker)
    local pillStroke = Instance.new("UIStroke", pill)
    pillStroke.Thickness = 1.5
    pillStroke.Transparency = defaultOn and 0.05 or 0.3
    pillStroke.Color = defaultOn and Config.NeonGlow or Config.PillOffBorder
    pillStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    pillStroke.Parent = pill

    -- Glow highlight
    local glow = Instance.new("Frame", pill)
    glow.Size = UDim2.new(0.6, 0, 0.6, 0)
    glow.Position = UDim2.new(0, 0, 0, 0)
    glow.BackgroundColor3 = Color3.fromRGB(255, 240, 255)
    glow.BackgroundTransparency = defaultOn and 0.35 or 0.75
    glow.BorderSizePixel = 0
    glow.ZIndex = 2
    Corner(glow, 999)

    local gg = Instance.new("UIGradient", glow)
    gg.Rotation = 135
    gg.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.6, 1),
        NumberSequenceKeypoint.new(1, 1),
    })
    gg.Parent = glow

    -- Knob
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = defaultOn
        and UDim2.new(1, -23, 0.5, -10)
        or UDim2.new(0, 3, 0.5, -10)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 6
    knob.Parent = pill
    Corner(knob, 999)

    local knobStroke = Instance.new("UIStroke", knob)
    knobStroke.Color = Config.NeonGlow
    knobStroke.Thickness = 1
    knobStroke.Transparency = 0.3
    knobStroke.Parent = knob

    local on = defaultOn
    local function Update()
        pillGrad.Color = on
            and ColorSequence.new(Config.NeonBright, Config.NeonDeep)
            or ColorSequence.new(Config.PillOff, Color3.fromRGB(30, 14, 52))

        pillStroke.Color = on and Config.NeonGlow or Config.PillOffBorder
        pillStroke.Transparency = on and 0.05 or 0.3

        Tween:Create(glow, TweenInfo.new(0.22), {
            BackgroundTransparency = on and 0.35 or 0.75,
        }):Play()

        Tween:Create(knob, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = on
                and UDim2.new(1, -23, 0.5, -10)
                or UDim2.new(0, 3, 0.5, -10),
        }):Play()
    end

    pill.MouseButton1Click:Connect(function()
        on = not on
        Update()
        if callback then callback(on) end
    end)

    return {
        Set = function(v) on = v; Update() end,
        Get = function() return on end,
    }
end

--=====================================================================
-- SLIDER (bright)
--=====================================================================
local function Slider(parent, y, title, minV, maxV, defaultV, suffix, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 56)
    row.Position = UDim2.new(0, 0, 0, y)
    row.BackgroundTransparency = 1
    row.ZIndex = 4
    row.Parent = parent

    Label(row, title, UDim2.new(0.6, 0, 0, 14), UDim2.new(0, 14, 0, 0),
        Config.FontBold, 10.5, Config.Text)

    local valueLbl = Label(row, tostring(defaultV) .. (suffix or ""),
        UDim2.new(0.4, -14, 0, 14), UDim2.new(0.6, 0, 0, 0),
        Config.FontBold, 10.5, Config.NeonGlow, Enum.TextXAlignment.Right)

    Label(row, "-", UDim2.new(0, 10, 0, 20), UDim2.new(0, 14, 0, 22),
        Config.FontBold, 14, Config.NeonGlow, Enum.TextXAlignment.Center)

    Label(row, "+", UDim2.new(0, 10, 0, 20), UDim2.new(1, -24, 0, 22),
        Config.FontBold, 14, Config.NeonGlow, Enum.TextXAlignment.Center)

    local track = Instance.new("TextButton")
    track.Size = UDim2.new(1, -60, 0, 8)
    track.Position = UDim2.new(0, 30, 0, 28)
    track.BackgroundColor3 = Config.TrackBg
    track.BorderSizePixel = 0
    track.Text = ""
    track.AutoButtonColor = false
    track.ZIndex = 4
    track.Parent = row
    Corner(track, 999)

    -- Track border (visible)
    local trackStroke = Instance.new("UIStroke", track)
    trackStroke.Color = Config.TrackBorder
    trackStroke.Thickness = 1
    trackStroke.Transparency = 0.5
    trackStroke.Parent = track

    local rel0 = math.clamp((defaultV - minV) / (maxV - minV), 0, 1)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(rel0, 0, 1, 0)
    fill.BackgroundColor3 = Config.NeonBright
    fill.BorderSizePixel = 0
    fill.ZIndex = 5
    fill.Parent = track
    Corner(fill, 999)

    Gradient(fill, 0, ColorSequence.new(Config.NeonDeep, Config.NeonBright))

    local fillGlow = Instance.new("UIStroke", fill)
    fillGlow.Color = Config.NeonGlow
    fillGlow.Thickness = 1
    fillGlow.Transparency = 0.4
    fillGlow.Parent = fill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(rel0, -8, 0.5, -8)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 6
    knob.Parent = track
    Corner(knob, 999)

    local knobStroke = Instance.new("UIStroke", knob)
    knobStroke.Color = Config.NeonBright
    knobStroke.Thickness = 2
    knobStroke.Transparency = 0.2
    knobStroke.Parent = knob

    local dragging = false

    local function Apply(rel)
        rel = math.clamp(rel, 0, 1)
        local val = math.floor(minV + rel * (maxV - minV))
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -8, 0.5, -8)
        valueLbl.Text = tostring(val) .. (suffix or "")
        if callback then callback(val) end
    end

    local function SetFromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        Apply(rel)
    end

    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            SetFromX(inp.Position.X)
        end
    end)

    track.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
            SetFromX(inp.Position.X)
        end
    end)

    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    local btnMinus = Instance.new("TextButton")
    btnMinus.Size = UDim2.new(0, 20, 0, 20)
    btnMinus.Position = UDim2.new(0, 9, 0, 22)
    btnMinus.BackgroundTransparency = 1
    btnMinus.Text = ""
    btnMinus.ZIndex = 7
    btnMinus.Parent = row
    btnMinus.MouseButton1Click:Connect(function()
        local cur = tonumber(valueLbl.Text:match("%d+")) or defaultV
        Apply((cur - 1 - minV) / (maxV - minV))
    end)

    local btnPlus = Instance.new("TextButton")
    btnPlus.Size = UDim2.new(0, 20, 0, 20)
    btnPlus.Position = UDim2.new(1, -29, 0, 22)
    btnPlus.BackgroundTransparency = 1
    btnPlus.Text = ""
    btnPlus.ZIndex = 7
    btnPlus.Parent = row
    btnPlus.MouseButton1Click:Connect(function()
        local cur = tonumber(valueLbl.Text:match("%d+")) or defaultV
        Apply((cur + 1 - minV) / (maxV - minV))
    end)

    return {
        Set = function(v)
            Apply((v - minV) / (maxV - minV))
        end,
    }
end

--=====================================================================
-- CHECKBOX (bright)
--=====================================================================
local function Checkbox(parent, y, title, defaultOn, callback)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.Position = UDim2.new(0, 0, 0, y)
    row.BackgroundColor3 = Config.BgCard
    row.BackgroundTransparency = 0.35
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = false
    row.ZIndex = 4
    row.Parent = parent
    Corner(row, 8)

    Stroke(row, Config.BtnInactiveBorder, 1, 0.4)

    Label(row, title, UDim2.new(1, -60, 1, 0), UDim2.new(0, 14, 0, 0),
        Config.FontMedium, 11, Config.Text)

    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 22, 0, 22)
    box.Position = UDim2.new(1, -34, 0.5, -11)
    box.BackgroundColor3 = Config.PillOff
    box.BorderSizePixel = 0
    box.ZIndex = 4
    box.Parent = row
    Corner(box, 5)

    local boxGrad = Instance.new("UIGradient", box)
    boxGrad.Color = defaultOn
        and ColorSequence.new(Config.NeonBright, Config.NeonDeep)
        or ColorSequence.new(Config.PillOff, Color3.fromRGB(30, 14, 52))
    boxGrad.Parent = box

    local boxStroke = Instance.new("UIStroke", box)
    boxStroke.Color = defaultOn and Config.NeonGlow or Config.PillOffBorder
    boxStroke.Thickness = 1.3
    boxStroke.Transparency = defaultOn and 0.15 or 0.4
    boxStroke.Parent = box

    local check = Instance.new("TextLabel")
    check.Text = "✓"
    check.Font = Config.FontBold
    check.TextSize = 15
    check.TextColor3 = Color3.new(1, 1, 1)
    check.BackgroundTransparency = 1
    check.Size = UDim2.new(1, 0, 1, 0)
    check.TextTransparency = defaultOn and 0 or 1
    check.ZIndex = 5
    check.Parent = box

    local on = defaultOn
    local function Update()
        boxGrad.Color = on
            and ColorSequence.new(Config.NeonBright, Config.NeonDeep)
            or ColorSequence.new(Config.PillOff, Color3.fromRGB(30, 14, 52))
        boxStroke.Color = on and Config.NeonGlow or Config.PillOffBorder
        boxStroke.Transparency = on and 0.15 or 0.4
        Tween:Create(check, TweenInfo.new(0.18), { TextTransparency = on and 0 or 1 }):Play()
    end

    row.MouseButton1Click:Connect(function()
        on = not on
        Update()
        if callback then callback(on) end
    end)

    return {
        Set = function(v) on = v; Update() end,
        Get = function() return on end,
    }
end

--=====================================================================
-- DROPDOWN
--=====================================================================
local function Dropdown(parent, y, title, options, defaultIndex, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.Position = UDim2.new(0, 0, 0, y)
    row.BackgroundColor3 = Config.BgCard
    row.BackgroundTransparency = 0.35
    row.BorderSizePixel = 0
    row.ZIndex = 4
    row.Parent = parent
    Corner(row, 8)

    Stroke(row, Config.BtnInactiveBorder, 1, 0.4)

    Label(row, title, UDim2.new(0.4, 0, 1, 0), UDim2.new(0, 14, 0, 0),
        Config.FontMedium, 11, Config.Text)

    local selected = options[defaultIndex or 1]

    local valueLbl = Label(row, selected or "...",
        UDim2.new(0.4, -14, 1, 0), UDim2.new(0.4, 0, 0, 0),
        Config.Font, 11, Config.TextDim)

    Label(row, "∨", UDim2.new(0, 20, 1, 0), UDim2.new(1, -30, 0, 0),
        Config.FontBold, 12, Config.NeonGlow, Enum.TextXAlignment.Center)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 6
    btn.Parent = row

    local open = false
    local menu

    local function CloseMenu()
        if menu then
            menu:Destroy()
            menu = nil
        end
        open = false
    end

    btn.MouseButton1Click:Connect(function()
        if open then CloseMenu() return end
        open = true

        menu = Instance.new("Frame")
        menu.Size = UDim2.new(1, 0, 0, #options * 26)
        menu.Position = UDim2.new(0, 0, 1, 4)
        menu.BackgroundColor3 = Config.BgCardHi
        menu.BorderSizePixel = 0
        menu.ZIndex = 20
        menu.Parent = row
        Corner(menu, 8)

        Stroke(menu, Config.BtnInactiveBorder, 1, 0.3)

        for i, opt in ipairs(options) do
            local item = Instance.new("TextButton")
            item.Size = UDim2.new(1, -8, 0, 24)
            item.Position = UDim2.new(0, 4, 0, 2 + (i - 1) * 26)
            item.BackgroundColor3 = Config.NeonDeep
            item.BackgroundTransparency = 1
            item.BorderSizePixel = 0
            item.Text = opt
            item.Font = Config.Font
            item.TextSize = 11
            item.TextColor3 = Config.Text
            item.TextXAlignment = Enum.TextXAlignment.Left
            item.AutoButtonColor = false
            item.ZIndex = 21
            item.Parent = menu
            Corner(item, 6)

            item.MouseEnter:Connect(function()
                Tween:Create(item, TweenInfo.new(0.15), { BackgroundTransparency = 0.5 }):Play()
            end)
            item.MouseLeave:Connect(function()
                Tween:Create(item, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
            end)

            item.MouseButton1Click:Connect(function()
                valueLbl.Text = opt
                if callback then callback(opt, i) end
                CloseMenu()
            end)
        end
    end)

    return {
        Get = function() return valueLbl.Text end,
    }
end

--=====================================================================
-- BUILD UI
--=====================================================================
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

    -- Global blur (affects game behind UI for glass effect)
    local guiBlur = Instance.new("BlurEffect")
    guiBlur.Name = "AxionHubBlur_Internal"
    guiBlur.Size = Config.BlurSize
    guiBlur.Parent = Lighting

    gui.Destroying:Connect(function()
        pcall(function() guiBlur:Destroy() end)
    end)

    -- Mini mode button
    local miniBtn = Instance.new("TextButton")
    miniBtn.Name = "MiniBtn"
    miniBtn.Size = UDim2.new(0, 48, 0, 48)
    miniBtn.Position = UDim2.new(0, 20, 0, 100)
    miniBtn.BackgroundColor3 = Config.NeonDeep
    miniBtn.BorderSizePixel = 0
    miniBtn.Text = ""
    miniBtn.AutoButtonColor = false
    miniBtn.Visible = false
    miniBtn.Active = true
    miniBtn.Draggable = true
    miniBtn.Parent = gui
    Corner(miniBtn, 12)

    Gradient(miniBtn, 135, ColorSequence.new(Config.NeonBright, Config.NeonDeep))
    Stroke(miniBtn, Config.NeonGlow, 1.4, 0.2)

    Label(miniBtn, "◆", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
        Config.FontBold, 22, Config.NeonGlow, Enum.TextXAlignment.Center)

    -- Main window
    local win = Instance.new("Frame")
    win.Name = "Window"
    win.Size = UDim2.new(0, 580, 0, 420)
    win.Position = UDim2.new(0.5, -290, 0.5, -210)
    win.BackgroundColor3 = Config.BgDark
    win.BackgroundTransparency = Config.WindowTransparency
    win.BorderSizePixel = 0
    win.Active = true
    win.ClipsDescendants = true
    win.Parent = gui
    Corner(win, 16)

    -- Window gradient overlay (subtle)
    Gradient(win, 90, ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 14, 52)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 4, 18)),
    }))

    -- ============ SIDEBAR (glass) ============
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 155, 1, 0)
    sidebar.BackgroundColor3 = Config.BgSidebar
    sidebar.BackgroundTransparency = Config.SidebarTransparency   -- semi-transparent
    sidebar.BorderSizePixel = 0
    sidebar.Parent = win
    Corner(sidebar, 16)

    Gradient(sidebar, 90, ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(52, 26, 82)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 8, 34)),
    }))

    -- Sidebar glass edge
    local sbStroke = Instance.new("UIStroke", sidebar)
    sbStroke.Color = Config.NeonDeep
    sbStroke.Thickness = 1.2
    sbStroke.Transparency = 0.5
    sbStroke.Parent = sidebar

    -- Sidebar inner highlight (glassmorphism reflection)
    local sbHi = Instance.new("Frame", sidebar)
    sbHi.Size = UDim2.new(1, -2, 0, 1)
    sbHi.Position = UDim2.new(0, 1, 0, 1)
    sbHi.BackgroundColor3 = Color3.fromRGB(255, 240, 255)
    sbHi.BackgroundTransparency = 0.6
    sbHi.BorderSizePixel = 0
    sbHi.ZIndex = 2
    Corner(sbHi, 999)

    local logoBox = Instance.new("Frame")
    logoBox.Size = UDim2.new(0, 44, 0, 44)
    logoBox.Position = UDim2.new(0, 18, 0, 18)
    logoBox.BackgroundColor3 = Config.NeonDeep
    logoBox.BorderSizePixel = 0
    logoBox.ZIndex = 3
    logoBox.Parent = sidebar
    Corner(logoBox, 12)
    Gradient(logoBox, 135, ColorSequence.new(Config.NeonBright, Config.NeonDeep))
    Stroke(logoBox, Config.NeonGlow, 1.3, 0.15)

    Label(logoBox, "◆", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
        Config.FontBold, 22, Config.NeonGlow, Enum.TextXAlignment.Center)

    Label(sidebar, "AnimeDice",
        UDim2.new(1, -20, 0, 18), UDim2.new(0, 18, 0, 70),
        Config.FontBold, 15, Config.Text)

    Label(sidebar, "v" .. Config.Version,
        UDim2.new(1, -20, 0, 14), UDim2.new(0, 18, 0, 88),
        Config.Font, 10, Config.Muted)

    -- Sidebar tabs
    local pages = {
        { Id = "MAIN", Icon = "🏠", Label = "Main", Desc = "dice & collect" },
        { Id = "SETTINGS", Icon = "⚙", Label = "Settings", Desc = "animation / range" },
    }

    local pageBtns = {}

    for i, p in ipairs(pages) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -24, 0, 44)
        btn.Position = UDim2.new(0, 12, 0, 132 + (i - 1) * 50)
        btn.BackgroundColor3 = Config.BgCard
        btn.BackgroundTransparency = 0.65
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.ZIndex = 3
        btn.Parent = sidebar
        Corner(btn, 10)

        Stroke(btn, Config.BtnInactiveBorder, 1, 0.5)

        local glow = Instance.new("Frame")
        glow.Size = UDim2.new(1, 0, 1, 0)
        glow.BackgroundColor3 = Config.NeonDeep
        glow.BackgroundTransparency = 0.6
        glow.BorderSizePixel = 0
        glow.Visible = false
        glow.ZIndex = 1
        glow.Parent = btn
        Corner(glow, 10)

        local badge = Instance.new("Frame")
        badge.Size = UDim2.new(0, 28, 0, 28)
        badge.Position = UDim2.new(0, 8, 0.5, -14)
        badge.BackgroundColor3 = Config.NeonDeep
        badge.BorderSizePixel = 0
        badge.ZIndex = 4
        badge.Parent = btn
        Corner(badge, 8)
        Gradient(badge, 135, ColorSequence.new(Config.NeonBright, Config.NeonDeep))

        Label(badge, p.Icon, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
            Config.FontBold, 14, Config.NeonGlow, Enum.TextXAlignment.Center)

        local nameLbl = Label(btn, p.Label,
            UDim2.new(1, -50, 0, 14), UDim2.new(0, 44, 0, 7),
            Config.FontBold, 11.5, Config.TextDim)

        Label(btn, p.Desc,
            UDim2.new(1, -50, 0, 12), UDim2.new(0, 44, 0, 23),
            Config.Font, 9, Config.Muted)

        pageBtns[p.Id] = {
            Btn = btn,
            Glow = glow,
            Name = nameLbl,
        }
    end

    -- ============ CONTENT (purple gradient, darker than sidebar) ============
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -155, 1, 0)
    content.Position = UDim2.new(0, 155, 0, 0)
    content.BackgroundColor3 = Config.BgTop
    content.BackgroundTransparency = Config.ContentTransparency
    content.BorderSizePixel = 0
    content.Parent = win

    -- Content gradient: lighter purple top → deep purple bottom
    local contentGrad = Instance.new("UIGradient", content)
    contentGrad.Rotation = 90
    contentGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Config.BgTop),
        ColorSequenceKeypoint.new(1.00, Config.BgBot),
    })
    contentGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, Config.ContentTransparency),
        NumberSequenceKeypoint.new(1.0, Config.ContentTransparency + 0.1),
    })
    contentGrad.Parent = content

    -- ============ MAIN PAGE ============
    local mainPage = Instance.new("Frame")
    mainPage.Size = UDim2.new(1, 0, 1, 0)
    mainPage.BackgroundTransparency = 1
    mainPage.Parent = content

    local scrollMain = Instance.new("ScrollingFrame")
    scrollMain.Size = UDim2.new(1, -36, 1, -32)
    scrollMain.Position = UDim2.new(0, 18, 0, 16)
    scrollMain.BackgroundTransparency = 1
    scrollMain.BorderSizePixel = 0
    scrollMain.ScrollBarThickness = 3
    scrollMain.ScrollBarImageColor3 = Config.NeonDeep
    scrollMain.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollMain.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollMain.Parent = mainPage

    local mainLayout = Instance.new("UIListLayout")
    mainLayout.Padding = UDim.new(0, 8)
    mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
    mainLayout.Parent = scrollMain

    -- Status header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 46)
    header.BackgroundColor3 = Config.BgCard
    header.BackgroundTransparency = Config.CardTransparency
    header.BorderSizePixel = 0
    header.LayoutOrder = 1
    header.Parent = scrollMain
    Corner(header, 10)
    Gradient(header, 90, ColorSequence.new(Config.BgCardHi, Config.BgCard))
    Stroke(header, Config.NeonDeep, 1, 0.4)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.Position = UDim2.new(0, 14, 0.5, -4)
    dot.BackgroundColor3 = Config.Muted
    dot.BorderSizePixel = 0
    dot.ZIndex = 5
    dot.Parent = header
    Corner(dot, 999)

    local statusTxt = Label(header, "READY",
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

    -- MODE card
    local modeCard = Instance.new("Frame")
    modeCard.Size = UDim2.new(1, 0, 0, 106)
    modeCard.BackgroundColor3 = Config.BgCard
    modeCard.BackgroundTransparency = Config.CardTransparency
    modeCard.BorderSizePixel = 0
    modeCard.LayoutOrder = 2
    modeCard.Parent = scrollMain
    Corner(modeCard, 10)
    Gradient(modeCard, 90, ColorSequence.new(Config.BgCardHi, Config.BgCard))
    Stroke(modeCard, Config.NeonDeep, 1, 0.4)
    AccentBar(modeCard)

    Label(modeCard, "MODE",
        UDim2.new(1, -28, 0, 14), UDim2.new(0, 20, 0, 8),
        Config.FontBold, 9.5, Config.NeonGlow)

    local modes = { "AUTO", "SPAM", "BOTH" }
    local modeBtns = {}

    for i, m in ipairs(modes) do
        local mb = Instance.new("TextButton")
        mb.Size = UDim2.new(0, 82, 0, 32)
        mb.Position = UDim2.new(0, 20 + (i - 1) * 88, 0, 26)
        mb.BackgroundColor3 = Config.BtnInactive
        mb.BackgroundTransparency = 0.15
        mb.BorderSizePixel = 0
        mb.Text = m
        mb.Font = Config.FontBold
        mb.TextSize = 11
        mb.TextColor3 = Config.Text
        mb.AutoButtonColor = false
        mb.ZIndex = 4
        mb.Parent = modeCard
        Corner(mb, 8)

        local mbStroke = Instance.new("UIStroke", mb)
        mbStroke.Color = Config.BtnInactiveBorder
        mbStroke.Thickness = 1.2
        mbStroke.Transparency = 0.35
        mbStroke.Parent = mb

        modeBtns[m] = { Btn = mb, Stroke = mbStroke }

        mb.MouseButton1Click:Connect(function()
            State.Mode = m
            for key, data in pairs(modeBtns) do
                local on = (key == State.Mode)
                data.Btn.BackgroundColor3 = on and Config.NeonBright or Config.BtnInactive
                data.Btn.BackgroundTransparency = on and 0.05 or 0.15
                data.Btn.TextColor3 = on and Color3.new(1, 1, 1) or Config.Text
                data.Stroke.Color = on and Config.NeonGlow or Config.BtnInactiveBorder
                data.Stroke.Transparency = on and 0.1 or 0.35
            end
        end)
    end

    for key, data in pairs(modeBtns) do
        local on = (key == State.Mode)
        data.Btn.BackgroundColor3 = on and Config.NeonBright or Config.BtnInactive
        data.Btn.BackgroundTransparency = on and 0.05 or 0.15
        data.Btn.TextColor3 = on and Color3.new(1, 1, 1) or Config.Text
        data.Stroke.Color = on and Config.NeonGlow or Config.BtnInactiveBorder
        data.Stroke.Transparency = on and 0.1 or 0.35
    end

    -- Auto Roll toggle
    local arToggle = Toggle(modeCard, 66, "🎲 Auto Roll", State.Running, function(v)
        if v then StartDice() else StopDice() end
    end)
    arToggle.Set(State.Running)

    -- SPAM SPEED slider
    local speedCard = Instance.new("Frame")
    speedCard.Size = UDim2.new(1, 0, 0, 62)
    speedCard.BackgroundColor3 = Config.BgCard
    speedCard.BackgroundTransparency = Config.CardTransparency
    speedCard.BorderSizePixel = 0
    speedCard.LayoutOrder = 3
    speedCard.Parent = scrollMain
    Corner(speedCard, 10)
    Gradient(speedCard, 90, ColorSequence.new(Config.BgCardHi, Config.BgCard))
    Stroke(speedCard, Config.NeonDeep, 1, 0.4)
    AccentBar(speedCard)

    Slider(speedCard, 10, "Spam Speed", 20, 200, 33, " /sec", function(v)
        State.SpamSpeed = 1 / v
    end)

    -- COLLECT card
    local collectCard = Instance.new("Frame")
    collectCard.Size = UDim2.new(1, 0, 0, 62)
    collectCard.BackgroundColor3 = Config.BgCard
    collectCard.BackgroundTransparency = Config.CardTransparency
    collectCard.BorderSizePixel = 0
    collectCard.LayoutOrder = 4
    collectCard.Parent = scrollMain
    Corner(collectCard, 10)
    Gradient(collectCard, 90, ColorSequence.new(Config.BgCardHi, Config.BgCard))
    Stroke(collectCard, Config.NeonDeep, 1, 0.4)
    AccentBar(collectCard)

    Toggle(collectCard, 11, "💰 AFK Collect Money", State.AutoCollect, function(v)
        if v then StartCollect() else StopCollect() end
    end)

    Label(collectCard,
        string.format("every %.1fs · plot %d→%d",
            State.CollectRate, State.PlotMin, State.PlotMax),
        UDim2.new(1, -28, 0, 14), UDim2.new(0, 20, 0, 42),
        Config.Font, 9, Config.NeonGlow)

    -- ============ SETTINGS PAGE ============
    local settingsPage = Instance.new("Frame")
    settingsPage.Size = UDim2.new(1, 0, 1, 0)
    settingsPage.BackgroundTransparency = 1
    settingsPage.Visible = false
    settingsPage.Parent = content

    local scrollSet = Instance.new("ScrollingFrame")
    scrollSet.Size = UDim2.new(1, -36, 1, -32)
    scrollSet.Position = UDim2.new(0, 18, 0, 16)
    scrollSet.BackgroundTransparency = 1
    scrollSet.BorderSizePixel = 0
    scrollSet.ScrollBarThickness = 3
    scrollSet.ScrollBarImageColor3 = Config.NeonDeep
    scrollSet.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollSet.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollSet.Parent = settingsPage

    local setLayout = Instance.new("UIListLayout")
    setLayout.Padding = UDim.new(0, 8)
    setLayout.SortOrder = Enum.SortOrder.LayoutOrder
    setLayout.Parent = scrollSet

    local sHeader = Instance.new("Frame")
    sHeader.Size = UDim2.new(1, 0, 0, 46)
    sHeader.BackgroundColor3 = Config.BgCard
    sHeader.BackgroundTransparency = Config.CardTransparency
    sHeader.BorderSizePixel = 0
    sHeader.LayoutOrder = 1
    sHeader.Parent = scrollSet
    Corner(sHeader, 10)
    Gradient(sHeader, 90, ColorSequence.new(Config.BgCardHi, Config.BgCard))
    Stroke(sHeader, Config.NeonDeep, 1, 0.4)

    Label(sHeader, "⚙  Settings",
        UDim2.new(1, -30, 1, 0), UDim2.new(0, 20, 0, 0),
        Config.FontBold, 12, Config.Text)

    -- Animation toggles
    local animCard = Instance.new("Frame")
    animCard.Size = UDim2.new(1, 0, 0, 102)
    animCard.BackgroundColor3 = Config.BgCard
    animCard.BackgroundTransparency = Config.CardTransparency
    animCard.BorderSizePixel = 0
    animCard.LayoutOrder = 2
    animCard.Parent = scrollSet
    Corner(animCard, 10)
    Gradient(animCard, 90, ColorSequence.new(Config.BgCardHi, Config.BgCard))
    Stroke(animCard, Config.NeonDeep, 1, 0.4)
    AccentBar(animCard)

    Toggle(animCard, 12, "Bypass Roll Animation", State.BypassAnim, function(v)
        State.BypassAnim = v
    end)

    Toggle(animCard, 58, "Kill Camera Cutscene", State.KillCutscene, function(v)
        State.KillCutscene = v
    end)

    -- Plot Range card
    local rangeCard = Instance.new("Frame")
    rangeCard.Size = UDim2.new(1, 0, 0, 76)
    rangeCard.BackgroundColor3 = Config.BgCard
    rangeCard.BackgroundTransparency = Config.CardTransparency
    rangeCard.BorderSizePixel = 0
    rangeCard.LayoutOrder = 3
    rangeCard.Parent = scrollSet
    Corner(rangeCard, 10)
    Gradient(rangeCard, 90, ColorSequence.new(Config.BgCardHi, Config.BgCard))
    Stroke(rangeCard, Config.NeonDeep, 1, 0.4)
    AccentBar(rangeCard)

    Label(rangeCard, "PLOT RANGE",
        UDim2.new(1, -28, 0, 14), UDim2.new(0, 20, 0, 8),
        Config.FontBold, 9.5, Config.NeonGlow)

    local rcVal = Label(rangeCard,
        string.format("1 → %d", State.PlotMax),
        UDim2.new(1, -28, 0, 14), UDim2.new(0, 20, 0, 26),
        Config.Font, 10, Config.Text)

    local function RangeBtn(txt, xPos, val)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 52, 0, 26)
        b.Position = UDim2.new(0, xPos, 0, 44)
        b.BackgroundColor3 = Config.NeonDeep
        b.BackgroundTransparency = 0.1
        b.Text = txt
        b.Font = Config.FontBold
        b.TextSize = 10
        b.TextColor3 = Config.Text
        b.AutoButtonColor = false
        b.ZIndex = 4
        b.Parent = rangeCard
        Corner(b, 8)

        local bs = Instance.new("UIStroke", b)
        bs.Color = Config.NeonBright
        bs.Thickness = 1.2
        bs.Transparency = 0.25
        bs.Parent = b

        b.MouseEnter:Connect(function()
            Tween:Create(b, TweenInfo.new(0.15), {
                BackgroundColor3 = Config.NeonBright,
                BackgroundTransparency = 0.05,
            }):Play()
        end)
        b.MouseLeave:Connect(function()
            Tween:Create(b, TweenInfo.new(0.15), {
                BackgroundColor3 = Config.NeonDeep,
                BackgroundTransparency = 0.1,
            }):Play()
        end)

        b.MouseButton1Click:Connect(function()
            State.PlotMin = 1
            State.PlotMax = val
            rcVal.Text = string.format("1 → %d", State.PlotMax)
        end)
    end

    RangeBtn("1 → 4", 20, 4)
    RangeBtn("1 → 8", 78, 8)
    RangeBtn("1 → 16", 136, 16)

    -- ============ PAGE SWITCH ============
    local function ApplyPage()
        for id, data in pairs(pageBtns) do
            local on = (id == State.Page)
            data.Glow.Visible = on
            data.Name.TextColor3 = on and Config.Text or Config.TextDim
            data.Btn.BackgroundTransparency = on and 0.2 or 0.65
            data.Btn.BackgroundColor3 = on and Config.NeonDeep or Config.BgCard
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

    -- ============ TOP BUTTONS ============
    local topBtns = Instance.new("Frame")
    topBtns.Size = UDim2.new(0, 60, 0, 22)
    topBtns.Position = UDim2.new(1, -70, 0, 10)
    topBtns.BackgroundTransparency = 1
    topBtns.ZIndex = 10
    topBtns.Parent = win

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 22, 0, 22)
    minBtn.Position = UDim2.new(0, 0, 0, 0)
    minBtn.BackgroundColor3 = Config.NeonDeep
    minBtn.BackgroundTransparency = 0.2
    minBtn.BorderSizePixel = 0
    minBtn.Text = "—"
    minBtn.Font = Config.FontBold
    minBtn.TextSize = 14
    minBtn.TextColor3 = Config.Text
    minBtn.AutoButtonColor = false
    minBtn.ZIndex = 11
    minBtn.Parent = topBtns
    Corner(minBtn, 999)
    Stroke(minBtn, Config.NeonBright, 1, 0.3)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(0, 32, 0, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(140, 40, 60)
    closeBtn.BackgroundTransparency = 0.1
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "✕"
    closeBtn.Font = Config.FontBold
    closeBtn.TextSize = 12
    closeBtn.TextColor3 = Config.Text
    closeBtn.AutoButtonColor = false
    closeBtn.ZIndex = 11
    closeBtn.Parent = topBtns
    Corner(closeBtn, 999)
    Stroke(closeBtn, Color3.fromRGB(255, 120, 140), 1, 0.3)

    minBtn.MouseButton1Click:Connect(function()
        State.Minimized = true
        win.Visible = false
        miniBtn.Visible = true
        guiBlur.Size = 0
    end)

    closeBtn.MouseButton1Click:Connect(function()
        pcall(StopDice)
        pcall(StopCollect)
        pcall(function() guiBlur:Destroy() end)
        pcall(function() gui:Destroy() end)
    end)

    miniBtn.MouseButton1Click:Connect(function()
        State.Minimized = false
        win.Visible = true
        miniBtn.Visible = false
        guiBlur.Size = Config.BlurSize
    end)

    -- Drag
    local draggingWin = false
    local dragStart, startPos

    local function StartDrag(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            draggingWin = true
            dragStart = inp.Position
            startPos = win.Position
        end
    end

    header.InputBegan:Connect(StartDrag)

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

--=====================================================================
-- LAUNCH
--=====================================================================
local ok, err = pcall(BuildUI)
if not ok then
    warn("[AnimeDice] BuildUI Error: " .. tostring(err))
    pcall(function()
        local b = Lighting:FindFirstChild("AxionHubBlur_Internal")
        if b then b:Destroy() end
    end)
end
