--[[
    AxionHub :: AutoDice  v2
    Anime Dice auto-roll — args confirmed from runtime spy
      RollDice:InvokeServer()          -- no args
      SetAutoRoll:FireServer(true)     -- bool
    UI: PURPLE → BLACK gradient theme
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Lighting          = game:GetService("Lighting")

local LP = Players.LocalPlayer
local RS = ReplicatedStorage

print("[AxionHub] ===== AutoDice v2 starting =====")

--=====================================================================
-- SAFE GUI PARENT (for executors)
--=====================================================================
local function getSafeGuiParent()
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    if syn and syn.protect_gui then
        local ok = pcall(function() return syn.protect_gui end)
        if ok then return game:GetService("CoreGui") end
    end
    return game:GetService("CoreGui")
end

--=====================================================================
-- SAFE REMOTE FINDER (no crash on nil)
--=====================================================================
local function safeFind(root, ...)
    local node = root
    for _, name in ipairs({...}) do
        if not node then return nil end
        local ok, child = pcall(function() return node:WaitForChild(name, 4) end)
        if not ok or not child then return nil end
        node = child
    end
    return node
end

local RollDice    = safeFind(RS, "Network", "RollService", "RF", "RollDice")
local SetAutoRoll = safeFind(RS, "Network", "RollService", "RE", "SetAutoRoll")
local RollMessage = safeFind(RS, "Network", "RollService", "RE", "RollMessage")

print("[AxionHub] RollDice   =", RollDice)
print("[AxionHub] SetAutoRoll =", SetAutoRoll)
print("[AxionHub] RollMessage =", RollMessage)

local remotesReady = (RollDice ~= nil) and (SetAutoRoll ~= nil)
if not remotesReady then
    warn("[AxionHub] Remotes NOT found — UI will load but buttons disabled.")
end

--=====================================================================
-- THEME :: PURPLE → BLACK
--=====================================================================
local Theme = {
    -- Gradient stops (violet → deep black)
    BgTop    = Color3.fromRGB(45, 12, 78),    -- vivid purple
    BgMid    = Color3.fromRGB(22, 8, 42),     -- mid purple
    BgBottom = Color3.fromRGB(6, 4, 12),      -- near black

    -- Accent (bright violet)
    Accent   = Color3.fromRGB(168, 85, 247),
    Accent2  = Color3.fromRGB(124, 58, 237),
    AccentLt = Color3.fromRGB(216, 180, 254),

    -- Text
    Text     = Color3.fromRGB(245, 240, 255),
    SubText  = Color3.fromRGB(180, 160, 215),
    Muted    = Color3.fromRGB(120, 100, 150),

    -- Structural
    Border   = Color3.fromRGB(140, 75, 220),
    Box      = Color3.fromRGB(30, 14, 52),
    SubBox   = Color3.fromRGB(42, 22, 70),
    Button   = Color3.fromRGB(58, 28, 100),
    ButtonHv = Color3.fromRGB(120, 55, 210),

    -- Status
    Good     = Color3.fromRGB(160, 255, 190),
    Bad      = Color3.fromRGB(255, 100, 120),
}

--=====================================================================
-- STATE
--=====================================================================
local State = {
    mode        = "AUTO",
    running     = false,
    rolls       = 0,
    autoRollOn  = false,
    thread      = nil,
    spamSpeed   = 0.05,
    results     = {},
}

--=====================================================================
-- ANIMATION SUPPRESSION
--=====================================================================
local function suppressAnimation()
    pcall(function()
        local rolling = RS:FindFirstChild("Framework")
                        and RS.Framework.Features
                        and RS.Framework.Features:FindFirstChild("Rolling")
        if rolling then
            local rc = rolling:FindFirstChild("RollCutscene")
            if rc then
                local cam = rc:FindFirstChild("CameraModel")
                if cam then cam:Destroy() end
            end
        end
    end)

    pcall(function()
        for _, name in ipairs({"VFXImpactFrameWhite","WhiteImpactFrame","BlackImpactFrame","VFXImpactFrameBlack"}) do
            local fx = Lighting:FindFirstChild(name)
            if fx and fx:IsA("ColorCorrectionEffect") then
                fx.Enabled = false
            end
        end
    end)

    pcall(function()
        local pg = LP:FindFirstChildOfClass("PlayerGui")
        if pg then
            local root = pg:FindFirstChild("Root")
            if root and root:FindFirstChild("Rolling") then
                root.Rolling.Visible = false
            end
        end
    end)
end
suppressAnimation()

--=====================================================================
-- ROLL LOGIC
--=====================================================================
local function doRoll()
    if not RollDice then return false end
    local ok = pcall(function()
        RollDice:InvokeServer()
    end)
    if ok then State.rolls = State.rolls + 1 end

    if (State.mode == "AUTO" or State.mode == "BOTH")
       and not State.autoRollOn and SetAutoRoll then
        pcall(function()
            SetAutoRoll:FireServer(true)
            State.autoRollOn = true
        end)
    end
    return ok
end

local function loop()
    State.running = true
    while State.running do
        if State.mode == "SPAM" or State.mode == "BOTH" then
            doRoll()
        elseif State.mode == "AUTO" then
            if not State.autoRollOn and SetAutoRoll then
                pcall(function()
                    SetAutoRoll:FireServer(true)
                    State.autoRollOn = true
                end)
            end
        end
        task.wait(State.spamSpeed)
    end
end

local function start()
    if State.running then return end
    if not remotesReady then
        warn("[AxionHub] Cannot start — remotes not loaded.")
        return
    end
    State.thread = task.spawn(loop)
end

local function stop()
    State.running = false
    if State.thread then pcall(task.cancel, State.thread) end
    if State.autoRollOn and SetAutoRoll then
        pcall(function() SetAutoRoll:FireServer(false) end)
        State.autoRollOn = false
    end
end

if RollMessage then
    RollMessage.OnClientEvent:Connect(function(...)
        table.insert(State.results, { time = os.time(), args = {...} })
        if #State.results > 200 then table.remove(State.results, 1) end
    end)
end

--=====================================================================
-- UI
--=====================================================================
local function buildUI()
    print("[AxionHub] buildUI() called")

    local parent = getSafeGuiParent()
    print("[AxionHub] GUI parent =", parent)

    local existing = parent:FindFirstChild("AxionHub_AutoDice")
    if existing then existing:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "AxionHub_AutoDice"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999
    gui.Parent = parent

    print("[AxionHub] ScreenGui created, parent =", gui.Parent)

    -- ========== Main Frame ==========
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 400, 0, 400)
    main.Position = UDim2.new(0.5, -200, 0.5, -200)
    main.BackgroundColor3 = Theme.BgBottom
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.ClipsDescendants = false
    main.Parent = gui

    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)

    -- Purple → Black gradient
    local grad = Instance.new("UIGradient")
    grad.Rotation = 90
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0.00, Theme.BgTop),
        ColorSequenceKeypoint.new(0.45, Theme.BgMid),
        ColorSequenceKeypoint.new(1.00, Theme.BgBottom),
    }
    grad.Parent = main

    -- Outer stroke with gradient glow
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.6
    stroke.Transparency = 0.15
    stroke.Parent = main
    local strokeGrad = Instance.new("UIGradient")
    strokeGrad.Rotation = 45
    strokeGrad.Color = ColorSequence.new(Theme.Accent, Theme.Accent2)
    strokeGrad.Parent = stroke

    -- ========== Header ==========
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundColor3 = Theme.BgTop
    header.BorderSizePixel = 0
    header.Parent = main
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 14)

    local headerGrad = Instance.new("UIGradient")
    headerGrad.Rotation = 0
    headerGrad.Color = ColorSequence.new(Theme.Accent2, Theme.BgTop)
    headerGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.05),
        NumberSequenceKeypoint.new(1, 0.85),
    })
    headerGrad.Parent = header

    -- fill bottom gap so corner shape sticks
    local hFix = Instance.new("Frame")
    hFix.Size = UDim2.new(1, 0, 0, 14)
    hFix.Position = UDim2.new(0, 0, 1, -14)
    hFix.BackgroundColor3 = Theme.BgTop
    hFix.BackgroundTransparency = 0.4
    hFix.BorderSizePixel = 0
    hFix.Parent = header

    local title = Instance.new("TextLabel")
    title.Text = "◆  AxionHub  •  AutoDice"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Theme.Text
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 16, 0, 0)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local close = Instance.new("TextButton")
    close.Text = "✕"
    close.Font = Enum.Font.GothamBold
    close.TextSize = 15
    close.TextColor3 = Theme.Text
    close.BackgroundTransparency = 1
    close.Size = UDim2.new(0, 36, 0, 36)
    close.Position = UDim2.new(1, -42, 0, 6)
    close.AutoButtonColor = false
    close.Parent = header
    close.MouseEnter:Connect(function() close.TextColor3 = Theme.Bad end)
    close.MouseLeave:Connect(function() close.TextColor3 = Theme.Text end)
    close.MouseButton1Click:Connect(function() stop(); gui:Destroy() end)

    -- ========== Status Bar ==========
    local statusBox = Instance.new("Frame")
    statusBox.Size = UDim2.new(1, -32, 0, 26)
    statusBox.Position = UDim2.new(0, 16, 0, 60)
    statusBox.BackgroundColor3 = Theme.Box
    statusBox.BackgroundTransparency = 0.35
    statusBox.BorderSizePixel = 0
    statusBox.Parent = main
    Instance.new("UICorner", statusBox).CornerRadius = UDim.new(0, 8)

    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 8, 0, 8)
    statusDot.Position = UDim2.new(0, 10, 0.5, -4)
    statusDot.BackgroundColor3 = Theme.Muted
    statusDot.BorderSizePixel = 0
    statusDot.Parent = statusBox
    Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

    local status = Instance.new("TextLabel")
    status.Font = Enum.Font.Gotham
    status.TextSize = 11
    status.TextColor3 = Theme.SubText
    status.BackgroundTransparency = 1
    status.Size = UDim2.new(1, -30, 1, 0)
    status.Position = UDim2.new(0, 26, 0, 0)
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = statusBox

    task.spawn(function()
        while status.Parent do
            local st = remotesReady and "READY" or "NO REMOTES"
            local color = remotesReady and (State.running and Theme.Good or Theme.AccentLt) or Theme.Bad
            status.Text = string.format("%s   •   mode: %s   •   rolls: %d   •   AR: %s",
                st, State.mode, State.rolls, State.autoRollOn and "ON" or "off")
            statusDot.BackgroundColor3 = color
            task.wait(0.25)
        end
    end)

    -- ========== Mode Selector ==========
    local modeRow = Instance.new("Frame")
    modeRow.Size = UDim2.new(1, -32, 0, 26)
    modeRow.Position = UDim2.new(0, 16, 0, 96)
    modeRow.BackgroundColor3 = Theme.Box
    modeRow.BackgroundTransparency = 0.5
    modeRow.BorderSizePixel = 0
    modeRow.Parent = main
    Instance.new("UICorner", modeRow).CornerRadius = UDim.new(0, 8)

    local modeLayout = Instance.new("UIListLayout", modeRow)
    modeLayout.FillDirection = Enum.FillDirection.Horizontal
    modeLayout.Padding = UDim.new(0, 4)
    modeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    modeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local modePad = Instance.new("UIPadding", modeRow)
    modePad.PaddingLeft = UDim.new(0, 4)
    modePad.PaddingRight = UDim.new(0, 4)

    local modeButtons = {}
    local modes = {"AUTO", "SPAM", "BOTH"}
    for _, m in ipairs(modes) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1/3, -4, 1, -6)
        btn.BackgroundColor3 = (State.mode == m) and Theme.ButtonHv or Color3.fromRGB(20, 10, 35)
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Text = m
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.TextColor3 = (State.mode == m) and Theme.Text or Theme.SubText
        btn.Parent = modeRow
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        local btnStroke = Instance.new("UIStroke", btn)
        btnStroke.Thickness = 1
        btnStroke.Transparency = 0.6
        btnStroke.Color = Theme.Border

        modeButtons[m] = btn

        btn.MouseButton1Click:Connect(function()
            State.mode = m
            for mm, bb in pairs(modeButtons) do
                local on = (mm == State.mode)
                bb.BackgroundColor3 = on and Theme.ButtonHv or Color3.fromRGB(20, 10, 35)
                bb.TextColor3 = on and Theme.Text or Theme.SubText
                local s = bb:FindFirstChildOfClass("UIStroke")
                if s then s.Transparency = on and 0.1 or 0.6 end
            end
        end)
    end

    -- ========== Speed Slider ==========
    local speedLabel = Instance.new("TextLabel")
    speedLabel.Text = "SPAM SPEED"
    speedLabel.Font = Enum.Font.GothamBold
    speedLabel.TextSize = 10
    speedLabel.TextColor3 = Theme.Muted
    speedLabel.BackgroundTransparency = 1
    speedLabel.Size = UDim2.new(0.5, 0, 0, 16)
    speedLabel.Position = UDim2.new(0, 16, 0, 134)
    speedLabel.TextXAlignment = Enum.TextXAlignment.Left
    speedLabel.Parent = main

    local speedVal = Instance.new("TextLabel")
    speedVal.Text = "20 / sec"
    speedVal.Font = Enum.Font.GothamBold
    speedVal.TextSize = 11
    speedVal.TextColor3 = Theme.AccentLt
    speedVal.BackgroundTransparency = 1
    speedVal.Size = UDim2.new(0.5, -16, 0, 16)
    speedVal.Position = UDim2.new(0.5, 0, 0, 134)
    speedVal.TextXAlignment = Enum.TextXAlignment.Right
    speedVal.Parent = main

    local track = Instance.new("TextButton")
    track.Size = UDim2.new(1, -32, 0, 8)
    track.Position = UDim2.new(0, 16, 0, 156)
    track.BackgroundColor3 = Theme.Box
    track.BorderSizePixel = 0
    track.Text = ""
    track.AutoButtonColor = false
    track.Parent = main
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0.5, 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local fillGrad = Instance.new("UIGradient")
    fillGrad.Color = ColorSequence.new(Theme.Accent2, Theme.AccentLt)
    fillGrad.Parent = fill

    local dragging = false
    local function setFromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        local rate = math.floor(50 + rel * 150)
        State.spamSpeed = 1 / rate
        speedVal.Text = rate .. " / sec"
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(input.Position.X)
        end
    end)
    track.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end)
    track.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- ========== Info panel ==========
    local infoBox = Instance.new("Frame")
    infoBox.Size = UDim2.new(1, -32, 0, 40)
    infoBox.Position = UDim2.new(0, 16, 0, 178)
    infoBox.BackgroundColor3 = Color3.fromRGB(15, 6, 28)
    infoBox.BackgroundTransparency = 0.5
    infoBox.BorderSizePixel = 0
    infoBox.Parent = main
    Instance.new("UICorner", infoBox).CornerRadius = UDim.new(0, 8)

    local infoStroke = Instance.new("UIStroke", infoBox)
    infoStroke.Color = Theme.Accent2
    infoStroke.Thickness = 1
    infoStroke.Transparency = 0.7

    local infoText = Instance.new("TextLabel")
    infoText.Text = remotesReady and
        "✔ remotes loaded\nRollDice()  |  SetAutoRoll(bool)" or
        "⚠ remotes NOT found\ncheck ReplicatedStorage.Network.RollService"
    infoText.Font = Enum.Font.Gotham
    infoText.TextSize = 10
    infoText.TextColor3 = remotesReady and Theme.SubText or Theme.Bad
    infoText.BackgroundTransparency = 1
    infoText.Size = UDim2.new(1, -16, 1, 0)
    infoText.Position = UDim2.new(0, 8, 0, 0)
    infoText.TextXAlignment = Enum.TextXAlignment.Left
    infoText.TextYAlignment = Enum.TextYAlignment.Center
    infoText.TextWrapped = true
    infoText.Parent = infoBox

    -- ========== Start / Stop ==========
    local startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.new(0.5, -24, 0, 44)
    startBtn.Position = UDim2.new(0, 16, 1, -60)
    startBtn.BackgroundColor3 = Theme.Button
    startBtn.BorderSizePixel = 0
    startBtn.Text = "▶  START"
    startBtn.Font = Enum.Font.GothamBold
    startBtn.TextSize = 13
    startBtn.TextColor3 = Theme.Text
    startBtn.AutoButtonColor = false
    startBtn.Parent = main
    Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 10)

    local sbGrad = Instance.new("UIGradient")
    sbGrad.Color = ColorSequence.new(Theme.Accent2, Theme.Accent)
    sbGrad.Rotation = 0
    sbGrad.Parent = startBtn
    sbGrad.Transparency = NumberSequence.new(0.35)

    local sbStroke = Instance.new("UIStroke", startBtn)
    sbStroke.Color = Theme.AccentLt
    sbStroke.Thickness = 1
    sbStroke.Transparency = 0.5

    local stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.new(0.5, -24, 0, 44)
    stopBtn.Position = UDim2.new(0.5, 8, 1, -60)
    stopBtn.BackgroundColor3 = Color3.fromRGB(45, 15, 30)
    stopBtn.BorderSizePixel = 0
    stopBtn.Text = "■  STOP"
    stopBtn.Font = Enum.Font.GothamBold
    stopBtn.TextSize = 13
    stopBtn.TextColor3 = Theme.Text
    stopBtn.AutoButtonColor = false
    stopBtn.Parent = main
    Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 10)

    local sb2Stroke = Instance.new("UIStroke", stopBtn)
    sb2Stroke.Color = Color3.fromRGB(180, 60, 90)
    sb2Stroke.Thickness = 1
    sb2Stroke.Transparency = 0.6

    local function flashBtn(btn, ok)
        local tw = TweenService:Create(btn, TweenInfo.new(0.18), {
            BackgroundColor3 = ok and Theme.Good or Theme.Bad
        })
        tw:Play()
        tw.Completed:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.35), {
                BackgroundColor3 = btn == startBtn and Theme.Button or Color3.fromRGB(45, 15, 30)
            }):Play()
        end)
    end

    startBtn.MouseButton1Click:Connect(function()
        if not remotesReady then return end
        start()
        startBtn.Text = "▶  RUNNING"
        startBtn.TextColor3 = Theme.Good
        flashBtn(startBtn, true)
    end)
    stopBtn.MouseButton1Click:Connect(function()
        stop()
        startBtn.Text = "▶  START"
        startBtn.TextColor3 = Theme.Text
        flashBtn(stopBtn, false)
    end)

    startBtn.MouseEnter:Connect(function() if remotesReady then startBtn.BackgroundColor3 = Theme.ButtonHv end end)
    startBtn.MouseLeave:Connect(function() startBtn.BackgroundColor3 = Theme.Button end)
    stopBtn.MouseEnter:Connect(function() stopBtn.BackgroundColor3 = Color3.fromRGB(70, 25, 45) end)
    stopBtn.MouseLeave:Connect(function() stopBtn.BackgroundColor3 = Color3.fromRGB(45, 15, 30) end)

    -- ========== Footer ==========
    local footer = Instance.new("TextLabel")
    footer.Text = "AxionHub v2  •  purple/black theme  •  args: RollDice(), SetAutoRoll(bool)"
    footer.Font = Enum.Font.Gotham
    footer.TextSize = 9
    footer.TextColor3 = Theme.Muted
    footer.BackgroundTransparency = 1
    footer.Size = UDim2.new(1, -32, 0, 14)
    footer.Position = UDim2.new(0, 16, 1, -18)
    footer.TextXAlignment = Enum.TextXAlignment.Left
    footer.Parent = main

    -- subtle purple glow pulse
    task.spawn(function()
        while gui.Parent do
            TweenService:Create(stroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Transparency = 0.45
            }):Play()
            task.wait(1.5)
            if not gui.Parent then break end
            TweenService:Create(stroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Transparency = 0.15
            }):Play()
            task.wait(1.5)
        end
    end)

    print("[AxionHub] buildUI() finished. Visible =", gui.Parent ~= nil)
end

--=====================================================================
-- BUILD UI FIRST (always, before any check)
--=====================================================================
local buildOk, buildErr = pcall(buildUI)
if not buildOk then
    warn("[AxionHub] buildUI ERROR:", buildErr)
end

print("[AxionHub] AutoDice v2 loaded. Press RightControl to toggle if hidden? (n/a) — drag from header.")