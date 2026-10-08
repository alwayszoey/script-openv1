--[[
    AxionHub AutoDice v7
    Changelog v6 → v7:
      ✔ UI ย้อนกลับธีมม่วงดำ
      ✔ Sidebar = glass (AxionHub + เมนู)
      ✔ Content bg = ดำไล่เฉด
      ✔ Card = ม่วงไล่เฉด
      ✔ คง AFK collect + auto dice ครบ
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")

local LP = Players.LocalPlayer
local RS = ReplicatedStorage

print("[AxionHub] ===== v7 starting =====")

--=====================================================================
-- THEME :: PURPLE / BLACK
--=====================================================================
local Theme = {
    -- Content bg — ดำไล่เฉด
    Bg1      = Color3.fromRGB(20,  6,  36),
    Bg2      = Color3.fromRGB(10,  3,  18),
    Bg3      = Color3.fromRGB(2,   0,   4),

    -- Card — ม่วงไล่เฉด
    Card1    = Color3.fromRGB(78,  30, 130),
    Card2    = Color3.fromRGB(48,  16, 88),
    Card3    = Color3.fromRGB(24,  6,  48),

    -- Sidebar (glass) — ม่วงเข้ม
    Sidebar  = Color3.fromRGB(24,  8,  46),

    Border   = Color3.fromRGB(90,  46, 152),
    BorderLt = Color3.fromRGB(160, 88, 250),

    Accent   = Color3.fromRGB(168, 85, 247),
    Accent2  = Color3.fromRGB(124, 58, 237),
    AccentLt = Color3.fromRGB(222, 192, 255),

    Text     = Color3.fromRGB(248, 244, 255),
    TextDim  = Color3.fromRGB(200, 180, 235),
    Muted    = Color3.fromRGB(140, 118, 178),

    Good     = Color3.fromRGB(130, 255, 180),
    Bad      = Color3.fromRGB(255, 100, 130),
    Gold     = Color3.fromRGB(255, 200, 80),
}

--=====================================================================
-- SAFE PARENT / FIND
--=====================================================================
local function getSafeGuiParent()
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

local RollDice    = safeFind(RS, "Network", "RollService", "RF", "RollDice")
local SetAutoRoll = safeFind(RS, "Network", "RollService", "RE", "SetAutoRoll")
local RollMessage = safeFind(RS, "Network", "RollService", "RE", "RollMessage")
local CollectBalance = safeFind(RS, "Network", "PlotService", "RE", "CollectBalance")

print("[AxionHub] RollDice       =", RollDice)
print("[AxionHub] SetAutoRoll    =", SetAutoRoll)
print("[AxionHub] CollectBalance =", CollectBalance)

local remotesReady = RollDice ~= nil and SetAutoRoll ~= nil
local collectReady = CollectBalance ~= nil

--=====================================================================
-- STATE
--=====================================================================
local State = {
    mode         = "AUTO",
    running      = false,
    rolls        = 0,
    autoRollOn   = false,
    thread       = nil,
    spamSpeed    = 0.03,
    bypassAnim   = true,
    killCutscene = true,
    results      = {},

    autoCollect   = false,
    collectThread = nil,
    collectRate   = 0.5,
    plotMin       = 1,
    plotMax       = 16,
    collected     = 0,
    lastPlot      = 0,
    collectStarted= false,
}

--=====================================================================
-- 🎬 ANIMATION BYPASS
--=====================================================================
local antiFX = { camModel=nil, cutscene=nil, rollingDir=nil, ccEffects={} }

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
        "VFXImpactFrameWhite","WhiteImpactFrame",
        "BlackImpactFrame","VFXImpactFrameBlack"
    }) do
        local fx = Lighting:FindFirstChild(name)
        if fx and fx:IsA("PostEffect") then
            antiFX.ccEffects[#antiFX.ccEffects+1] = fx
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

    local cam = Workspace.CurrentCamera
    if cam then
        local blur = cam:FindFirstChild("blur")
        if blur and blur:IsA("BlurEffect") and blur.Size > 0 then blur.Size = 0 end
        local cc = cam:FindFirstChild("cc")
        if cc and cc:IsA("ColorCorrectionEffect") then cc.Enabled = false end
    end
end

initAntiFX()
task.spawn(function()
    while true do
        task.wait(2)
        initAntiFX()
    end
end)
RunService.Heartbeat:Connect(tickAntiFX)

--=====================================================================
-- 🎲 ROLL LOGIC
--=====================================================================
local function doRoll()
    if not RollDice then return false end
    local ok = pcall(function() RollDice:InvokeServer() end)
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
    if State.running or not remotesReady then return end
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
-- 💰 AFK AUTO COLLECT
--=====================================================================
local function collectOnePlot(plotNum)
    if not CollectBalance then return end
    pcall(function()
        CollectBalance:FireServer(plotNum)
    end)
    State.collected = State.collected + 1
    State.lastPlot = plotNum
end

local function collectLoop()
    print("[AxionHub] 💰 AFK collect started")
    while State.autoCollect do
        for plotNum = State.plotMin, State.plotMax do
            if not State.autoCollect then break end
            collectOnePlot(plotNum)
            task.wait(0.04)
        end
        task.wait(State.collectRate)
    end
    print("[AxionHub] 💰 AFK collect stopped")
end

local function startCollect()
    if State.collectThread then return end
    if not collectReady then return end
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

-- Auto start
task.spawn(function()
    local tries = 0
    while not CollectBalance and tries < 30 do
        task.wait(0.5)
        tries = tries + 1
        CollectBalance = safeFind(RS, "Network", "PlotService", "RE", "CollectBalance")
    end
    if CollectBalance then
        print("[AxionHub] ✔ AFK collect auto-starting")
        startCollect()
        if remotesReady then
            task.wait(0.3)
            start()
            print("[AxionHub] ✔ Dice auto-starting")
        end
    end
end)

LP.CharacterAdded:Connect(function()
    task.wait(2)
    if State.collectStarted and not State.autoCollect then
        startCollect()
    end
end)

--=====================================================================
-- 🎨 UI BUILDER — Sidebar glass / Content ดำ / Card ม่วง
--=====================================================================
local function buildUI()
    print("[AxionHub] buildUI() called")

    local parent = getSafeGuiParent()
    local old = parent:FindFirstChild("AxionHub_AutoDice")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "AxionHub_AutoDice"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999
    gui.Parent = parent

    local blur = Instance.new("BlurEffect")
    blur.Name = "AxionGlassBlur"
    blur.Size = 14
    blur.Parent = Lighting
    gui.Destroying:Connect(function()
        pcall(function() blur:Destroy() end)
    end)

    -- ---------- Window ----------
    local win = Instance.new("Frame")
    win.Name = "Window"
    win.Size = UDim2.new(0, 580, 0, 400)
    win.Position = UDim2.new(0.5, -290, 0.5, -200)
    win.BackgroundColor3 = Theme.Bg2
    win.BackgroundTransparency = 0.1
    win.BorderSizePixel = 0
    win.Active = true
    win.ClipsDescendants = true
    win.Parent = gui
    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 16)

    -- ★ Content bg — ดำไล่เฉด (บนม่วงดำ → ล่างดำสนิท)
    local winGrad = Instance.new("UIGradient", win)
    winGrad.Rotation = 90
    winGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0.00, Theme.Bg1),
        ColorSequenceKeypoint.new(0.45, Theme.Bg2),
        ColorSequenceKeypoint.new(1.00, Theme.Bg3),
    }
    winGrad.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0.0, 0.05),
        NumberSequenceKeypoint.new(0.5, 0.15),
        NumberSequenceKeypoint.new(1.0, 0.25),
    }

    local winStroke = Instance.new("UIStroke", win)
    winStroke.Thickness = 1.6
    winStroke.Transparency = 0.15
    local strokeGrad = Instance.new("UIGradient", winStroke)
    strokeGrad.Rotation = 45
    strokeGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0.00, Theme.AccentLt),
        ColorSequenceKeypoint.new(0.50, Theme.Accent),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(40, 10, 70)),
    }

    -- ---------- SIDEBAR (Glass) ----------
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 155, 1, 0)
    sidebar.BackgroundColor3 = Theme.Sidebar
    sidebar.BackgroundTransparency = 0.25
    sidebar.BorderSizePixel = 0
    sidebar.Parent = win
    Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 16)

    -- Sidebar glass gradient (ม่วงเข้ม → ดำ)
    local sbGrad = Instance.new("UIGradient", sidebar)
    sbGrad.Rotation = 90
    sbGrad.Color = ColorSequence.new(
        Color3.fromRGB(42, 14, 76),
        Color3.fromRGB(6, 2, 14)
    )
    sbGrad.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 0.45),
    }

    -- Glass edge glow
    local sbStroke = Instance.new("UIStroke", sidebar)
    sbStroke.Thickness = 1.4
    sbStroke.Transparency = 0.2
    local sbStrokeGrad = Instance.new("UIGradient", sbStroke)
    sbStrokeGrad.Rotation = 45
    sbStrokeGrad.Color = ColorSequence.new(Theme.AccentLt, Theme.Accent2)

    -- Inner highlight (glass reflection)
    local sbHi = Instance.new("Frame", sidebar)
    sbHi.Size = UDim2.new(1, -2, 0, 1)
    sbHi.Position = UDim2.new(0, 1, 0, 1)
    sbHi.BackgroundColor3 = Color3.fromRGB(220, 180, 255)
    sbHi.BackgroundTransparency = 0.55
    sbHi.BorderSizePixel = 0
    Instance.new("UICorner", sbHi).CornerRadius = UDim.new(1, 0)

    local sbLine = Instance.new("Frame")
    sbLine.Size = UDim2.new(0, 1, 1, 0)
    sbLine.Position = UDim2.new(1, -1, 0, 0)
    sbLine.BackgroundColor3 = Theme.BorderLt
    sbLine.BackgroundTransparency = 0.6
    sbLine.BorderSizePixel = 0
    sbLine.Parent = sidebar

    -- Logo
    local logoBox = Instance.new("Frame")
    logoBox.Size = UDim2.new(0, 44, 0, 44)
    logoBox.Position = UDim2.new(0, 18, 0, 18)
    logoBox.BackgroundColor3 = Theme.Card2
    logoBox.BackgroundTransparency = 0.15
    logoBox.BorderSizePixel = 0
    logoBox.Parent = sidebar
    Instance.new("UICorner", logoBox).CornerRadius = UDim.new(0, 12)

    local logoS = Instance.new("UIStroke", logoBox)
    logoS.Thickness = 1.4
    logoS.Transparency = 0.1
    local logoSG = Instance.new("UIGradient", logoS)
    logoSG.Rotation = 45
    logoSG.Color = ColorSequence.new(Theme.AccentLt, Theme.Accent2)

    local logoIcon = Instance.new("TextLabel")
    logoIcon.Text = "◆"
    logoIcon.Font = Enum.Font.GothamBold
    logoIcon.TextSize = 22
    logoIcon.TextColor3 = Theme.AccentLt
    logoIcon.BackgroundTransparency = 1
    logoIcon.Size = UDim2.new(1, 0, 1, 0)
    logoIcon.Parent = logoBox

    local title = Instance.new("TextLabel")
    title.Text = "AxionHub"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextColor3 = Theme.Text
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -20, 0, 18)
    title.Position = UDim2.new(0, 18, 0, 70)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = sidebar

    local sub = Instance.new("TextLabel")
    sub.Text = "AutoDice  v7"
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 10
    sub.TextColor3 = Theme.Muted
    sub.BackgroundTransparency = 1
    sub.Size = UDim2.new(1, -20, 0, 14)
    sub.Position = UDim2.new(0, 18, 0, 88)
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = sidebar

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, -32, 0, 1)
    divider.Position = UDim2.new(0, 16, 0, 118)
    divider.BackgroundColor3 = Theme.Border
    divider.BackgroundTransparency = 0.5
    divider.BorderSizePixel = 0
    divider.Parent = sidebar

    -- Mode buttons
    local modes = {"AUTO", "SPAM", "BOTH"}
    local modeIcons = { "⟳", "⚡", "◈" }
    local modeDesc = {
        ["AUTO"] = "set & forget",
        ["SPAM"] = "20–200 /sec",
        ["BOTH"] = "autoroll + spam",
    }

    local sidebarBtns = {}
    local yBase = 132
    for i, m in ipairs(modes) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -24, 0, 44)
        btn.Position = UDim2.new(0, 12, 0, yBase + (i-1) * 50)
        btn.BackgroundColor3 = Theme.Card2
        btn.BackgroundTransparency = 0.8
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.Parent = sidebar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

        local bStroke = Instance.new("UIStroke", btn)
        bStroke.Thickness = 1
        bStroke.Transparency = 0.7
        bStroke.Color = Theme.Border

        local glow = Instance.new("Frame", btn)
        glow.Size = UDim2.new(1, 0, 1, 0)
        glow.BackgroundColor3 = Theme.Accent
        glow.BackgroundTransparency = 0.85
        glow.BorderSizePixel = 0
        glow.Visible = false
        Instance.new("UICorner", glow).CornerRadius = UDim.new(0, 10)

        local badge = Instance.new("Frame", btn)
        badge.Size = UDim2.new(0, 28, 0, 28)
        badge.Position = UDim2.new(0, 8, 0.5, -14)
        badge.BackgroundColor3 = Theme.Card1
        badge.BackgroundTransparency = 0.2
        badge.BorderSizePixel = 0
        Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 8)

        local icon = Instance.new("TextLabel", badge)
        icon.Text = modeIcons[i]
        icon.Font = Enum.Font.GothamBold
        icon.TextSize = 15
        icon.TextColor3 = Theme.AccentLt
        icon.BackgroundTransparency = 1
        icon.Size = UDim2.new(1, 0, 1, 0)

        local nameLbl = Instance.new("TextLabel", btn)
        nameLbl.Text = m
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 11.5
        nameLbl.TextColor3 = Theme.TextDim
        nameLbl.BackgroundTransparency = 1
        nameLbl.Size = UDim2.new(1, -50, 0, 14)
        nameLbl.Position = UDim2.new(0, 44, 0, 7)
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left

        local descLbl = Instance.new("TextLabel", btn)
        descLbl.Text = modeDesc[m]
        descLbl.Font = Enum.Font.Gotham
        descLbl.TextSize = 9
        descLbl.TextColor3 = Theme.Muted
        descLbl.BackgroundTransparency = 1
        descLbl.Size = UDim2.new(1, -50, 0, 12)
        descLbl.Position = UDim2.new(0, 44, 0, 23)
        descLbl.TextXAlignment = Enum.TextXAlignment.Left

        sidebarBtns[m] = { btn=btn, stroke=bStroke, glow=glow, name=nameLbl, icon=icon }

        btn.MouseEnter:Connect(function()
            if State.mode ~= m then
                TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundTransparency = 0.55 }):Play()
                TweenService:Create(nameLbl, TweenInfo.new(0.15), { TextColor3 = Theme.Text }):Play()
            end
        end)
        btn.MouseLeave:Connect(function()
            if State.mode ~= m then
                TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundTransparency = 0.8 }):Play()
                TweenService:Create(nameLbl, TweenInfo.new(0.15), { TextColor3 = Theme.TextDim }):Play()
            end
        end)

        btn.MouseButton1Click:Connect(function()
            State.mode = m
            for mm, data in pairs(sidebarBtns) do
                local on = (mm == State.mode)
                data.glow.Visible = on
                data.stroke.Transparency = on and 0.15 or 0.7
                data.stroke.Color = on and Theme.AccentLt or Theme.Border
                data.name.TextColor3 = on and Theme.Text or Theme.TextDim
                data.icon.TextColor3 = on and Theme.Text or Theme.AccentLt
                data.btn.BackgroundTransparency = on and 0.15 or 0.8
            end
        end)
    end

    for mm, data in pairs(sidebarBtns) do
        local on = (mm == State.mode)
        data.glow.Visible = on
        data.stroke.Transparency = on and 0.15 or 0.7
        data.stroke.Color = on and Theme.AccentLt or Theme.Border
        data.name.TextColor3 = on and Theme.Text or Theme.TextDim
        data.icon.TextColor3 = on and Theme.Text or Theme.AccentLt
        data.btn.BackgroundTransparency = on and 0.15 or 0.8
    end

    -- ---------- CONTENT ----------
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -155, 1, 0)
    content.Position = UDim2.new(0, 155, 0, 0)
    content.BackgroundTransparency = 1
    content.Parent = win

    -- ★ Card builder — ม่วงไล่เฉด
    local function makeCard(parent, size, pos)
        local card = Instance.new("Frame")
        card.Size = size
        card.Position = pos
        card.BackgroundColor3 = Theme.Card2
        card.BackgroundTransparency = 0.15
        card.BorderSizePixel = 0
        card.Parent = parent
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

        local grad = Instance.new("UIGradient", card)
        grad.Rotation = 90
        grad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0.00, Theme.Card1),
            ColorSequenceKeypoint.new(0.55, Theme.Card2),
            ColorSequenceKeypoint.new(1.00, Theme.Card3),
        }
        grad.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0.0, 0.1),
            NumberSequenceKeypoint.new(1.0, 0.35),
        }

        local stroke = Instance.new("UIStroke", card)
        stroke.Thickness = 1
        stroke.Transparency = 0.35
        local sGrad = Instance.new("UIGradient", stroke)
        sGrad.Rotation = 45
        sGrad.Color = ColorSequence.new(Theme.BorderLt, Theme.Accent2)

        return card
    end

    -- Header card
    local header = makeCard(content, UDim2.new(1, -36, 0, 46), UDim2.new(0, 18, 0, 16))

    local dot = Instance.new("Frame", header)
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.Position = UDim2.new(0, 14, 0.5, -4)
    dot.BackgroundColor3 = Theme.Muted
    dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local statusTxt = Instance.new("TextLabel", header)
    statusTxt.Font = Enum.Font.Gotham
    statusTxt.TextSize = 11
    statusTxt.TextColor3 = Theme.Text
    statusTxt.BackgroundTransparency = 1
    statusTxt.Size = UDim2.new(1, -40, 1, 0)
    statusTxt.Position = UDim2.new(0, 30, 0, 0)
    statusTxt.TextXAlignment = Enum.TextXAlignment.Left
    statusTxt.Text = "READY"

    task.spawn(function()
        while statusTxt.Parent do
            local ready = remotesReady
            local stat = ready and (State.running and "RUNNING" or "READY") or "NO REMOTES"
            local color = ready and (State.running and Theme.Good or Theme.AccentLt) or Theme.Bad
            statusTxt.Text = string.format("💤 AFK  ·  %s  ·  rolls: %d  ·  💰 %d",
                stat, State.rolls, State.collected)
            dot.BackgroundColor3 = color
            task.wait(0.2)
        end
    end)

    -- Speed card
    local speedCard = makeCard(content, UDim2.new(1, -36, 0, 62), UDim2.new(0, 18, 0, 76))

    local spdLbl = Instance.new("TextLabel", speedCard)
    spdLbl.Text = "SPAM SPEED"
    spdLbl.Font = Enum.Font.GothamBold
    spdLbl.TextSize = 9.5
    spdLbl.TextColor3 = Theme.AccentLt
    spdLbl.BackgroundTransparency = 1
    spdLbl.Size = UDim2.new(0.5, 0, 0, 14)
    spdLbl.Position = UDim2.new(0, 12, 0, 8)
    spdLbl.TextXAlignment = Enum.TextXAlignment.Left

    local spdVal = Instance.new("TextLabel", speedCard)
    spdVal.Text = "33 / sec"
    spdVal.Font = Enum.Font.GothamBold
    spdVal.TextSize = 11
    spdVal.TextColor3 = Theme.Text
    spdVal.BackgroundTransparency = 1
    spdVal.Size = UDim2.new(0.5, -12, 0, 14)
    spdVal.Position = UDim2.new(0.5, 0, 0, 8)
    spdVal.TextXAlignment = Enum.TextXAlignment.Right

    local track = Instance.new("TextButton", speedCard)
    track.Size = UDim2.new(1, -24, 0, 10)
    track.Position = UDim2.new(0, 12, 0, 36)
    track.BackgroundColor3 = Color3.fromRGB(10, 3, 20)
    track.BorderSizePixel = 0
    track.Text = ""
    track.AutoButtonColor = false
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame", track)
    fill.Size = UDim2.new(0.5, 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local fillG = Instance.new("UIGradient", fill)
    fillG.Color = ColorSequence.new(Theme.Accent2, Theme.AccentLt)

    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0.5, -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local knobS = Instance.new("UIStroke", knob)
    knobS.Color = Theme.AccentLt
    knobS.Thickness = 2

    local dragging = false
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
            dragging = true
            setFromX(inp.Position.X)
        end
    end)
    track.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch) then
            setFromX(inp.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- Toggles card
    local togCard = makeCard(content, UDim2.new(1, -36, 0, 138), UDim2.new(0, 18, 0, 148))

    local function makeToggle(parent, y, label, defaultOn, cb, tintColor)
        tintColor = tintColor or Theme.Accent

        local lbl = Instance.new("TextLabel", parent)
        lbl.Text = label
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 11
        lbl.TextColor3 = Theme.Text
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(0.75, 0, 0, 20)
        lbl.Position = UDim2.new(0, 14, 0, y)
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        local pill = Instance.new("TextButton", parent)
        pill.Size = UDim2.new(0, 36, 0, 20)
        pill.Position = UDim2.new(1, -50, 0, y)
        pill.BackgroundColor3 = defaultOn and tintColor or Color3.fromRGB(10, 3, 20)
        pill.Text = ""
        pill.AutoButtonColor = false
        Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

        local k = Instance.new("Frame", pill)
        k.Size = UDim2.new(0, 14, 0, 14)
        k.Position = defaultOn and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        k.BackgroundColor3 = Color3.new(1,1,1)
        k.BorderSizePixel = 0
        Instance.new("UICorner", k).CornerRadius = UDim.new(1, 0)

        local on = defaultOn
        local function update()
            TweenService:Create(pill, TweenInfo.new(0.2), {
                BackgroundColor3 = on and tintColor or Color3.fromRGB(10, 3, 20)
            }):Play()
            TweenService:Create(k, TweenInfo.new(0.2), {
                Position = on and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)
            }):Play()
        end

        pill.MouseButton1Click:Connect(function()
            on = not on
            update()
            if cb then cb(on) end
        end)

        return { Set = function(v) on = v; update() end }
    end

    makeToggle(togCard, 8,  "Bypass Roll Animation",
        State.bypassAnim,
        function(v) State.bypassAnim = v end)

    makeToggle(togCard, 34, "Kill Camera Cutscene",
        State.killCutscene,
        function(v) State.killCutscene = v end)

    makeToggle(togCard, 60, "💰 AFK Collect Money (Plot 1–16)",
        State.autoCollect,
        function(v)
            if v then startCollect() else stopCollect() end
        end,
        Theme.Gold)

    local cInfo = Instance.new("TextLabel", togCard)
    cInfo.Text = string.format("AFK mode  ·  every %.1fs  ·  plot %d→%d",
        State.collectRate, State.plotMin, State.plotMax)
    cInfo.Font = Enum.Font.Gotham
    cInfo.TextSize = 9
    cInfo.TextColor3 = Theme.AccentLt
    cInfo.BackgroundTransparency = 1
    cInfo.Size = UDim2.new(1, -28, 0, 14)
    cInfo.Position = UDim2.new(0, 14, 0, 88)
    cInfo.TextXAlignment = Enum.TextXAlignment.Left

    local function smallBtn(txt, xOff, onClick)
        local b = Instance.new("TextButton", togCard)
        b.Size = UDim2.new(0, 42, 0, 18)
        b.Position = UDim2.new(1, xOff, 0, 110)
        b.BackgroundColor3 = Theme.Card1
        b.BackgroundTransparency = 0.15
        b.Text = txt
        b.Font = Enum.Font.GothamBold
        b.TextSize = 9.5
        b.TextColor3 = Theme.Text
        b.AutoButtonColor = false
        Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)

        local s = Instance.new("UIStroke", b)
        s.Color = Theme.BorderLt
        s.Thickness = 1
        s.Transparency = 0.4

        b.MouseButton1Click:Connect(onClick)
        return b
    end

    smallBtn("4", -192, function()
        State.plotMin, State.plotMax = 1, 4
        cInfo.Text = string.format("AFK mode  ·  every %.1fs  ·  plot %d→%d",
            State.collectRate, State.plotMin, State.plotMax)
    end)
    smallBtn("8", -146, function()
        State.plotMin, State.plotMax = 1, 8
        cInfo.Text = string.format("AFK mode  ·  every %.1fs  ·  plot %d→%d",
            State.collectRate, State.plotMin, State.plotMax)
    end)
    smallBtn("16", -100, function()
        State.plotMin, State.plotMax = 1, 16
        cInfo.Text = string.format("AFK mode  ·  every %.1fs  ·  plot %d→%d",
            State.collectRate, State.plotMin, State.plotMax)
    end)

    local rangeLbl = Instance.new("TextLabel", togCard)
    rangeLbl.Text = "PLOT RANGE"
    rangeLbl.Font = Enum.Font.GothamBold
    rangeLbl.TextSize = 9
    rangeLbl.TextColor3 = Theme.Muted
    rangeLbl.BackgroundTransparency = 1
    rangeLbl.Size = UDim2.new(0, 80, 0, 14)
    rangeLbl.Position = UDim2.new(0, 14, 0, 112)
    rangeLbl.TextXAlignment = Enum.TextXAlignment.Left

    -- Info card
    local info = makeCard(content, UDim2.new(1, -36, 0, 44), UDim2.new(0, 18, 0, 296))

    local infoDot = Instance.new("Frame", info)
    infoDot.Size = UDim2.new(0, 6, 0, 6)
    infoDot.Position = UDim2.new(0, 14, 0, 10)
    infoDot.BackgroundColor3 = collectReady and Theme.Good or Theme.Bad
    infoDot.BorderSizePixel = 0
    Instance.new("UICorner", infoDot).CornerRadius = UDim.new(1, 0)

    local infoTxt = Instance.new("TextLabel", info)
    infoTxt.Text = string.format(
        "%s AFK COLLECT  ·  %s RollService\nPlotService.RE.CollectBalance(plotNumber)",
        collectReady and "✔" or "✘",
        remotesReady and "✔" or "✘"
    )
    infoTxt.Font = Enum.Font.Gotham
    infoTxt.TextSize = 10
    infoTxt.TextColor3 = Theme.Text
    infoTxt.BackgroundTransparency = 1
    infoTxt.Size = UDim2.new(1, -30, 1, 0)
    infoTxt.Position = UDim2.new(0, 26, 0, 0)
    infoTxt.TextXAlignment = Enum.TextXAlignment.Left
    infoTxt.TextYAlignment = Enum.TextYAlignment.Center
    infoTxt.TextWrapped = true

    -- Start / Stop buttons
    local startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.new(0.5, -26, 0, 42)
    startBtn.Position = UDim2.new(0, 18, 1, -58)
    startBtn.BorderSizePixel = 0
    startBtn.Text = "▶  START DICE"
    startBtn.Font = Enum.Font.GothamBold
    startBtn.TextSize = 13
    startBtn.TextColor3 = Theme.Text
    startBtn.AutoButtonColor = false
    startBtn.Parent = content
    Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 10)

    local sbG = Instance.new("UIGradient", startBtn)
    sbG.Rotation = 90
    sbG.Color = ColorSequence.new(Theme.Accent2, Theme.Accent)

    local sbSt = Instance.new("UIStroke", startBtn)
    sbSt.Color = Theme.AccentLt
    sbSt.Thickness = 1
    sbSt.Transparency = 0.3

    local stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.new(0.5, -26, 0, 42)
    stopBtn.Position = UDim2.new(0.5, 8, 1, -58)
    stopBtn.BorderSizePixel = 0
    stopBtn.Text = "■  STOP"
    stopBtn.Font = Enum.Font.GothamBold
    stopBtn.TextSize = 13
    stopBtn.TextColor3 = Theme.Text
    stopBtn.AutoButtonColor = false
    stopBtn.Parent = content
    Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 10)

    local stopGrad = Instance.new("UIGradient", stopBtn)
    stopGrad.Rotation = 90
    stopGrad.Color = ColorSequence.new(
        Color3.fromRGB(60, 20, 40),
        Color3.fromRGB(30, 8, 20)
    )

    local sbSt2 = Instance.new("UIStroke", stopBtn)
    sbSt2.Color = Color3.fromRGB(180, 60, 90)
    sbSt2.Thickness = 1
    sbSt2.Transparency = 0.5

    startBtn.MouseButton1Click:Connect(function()
        if not remotesReady then return end
        start()
        startBtn.Text = "▶  RUNNING"
        startBtn.TextColor3 = Theme.Good
    end)
    stopBtn.MouseButton1Click:Connect(function()
        stop()
        startBtn.Text = "▶  START DICE"
        startBtn.TextColor3 = Theme.Text
    end)

    local footer = Instance.new("TextLabel", win)
    footer.Text = "v7  ·  AFK collect  ·  purple/black"
    footer.Font = Enum.Font.Gotham
    footer.TextSize = 9
    footer.TextColor3 = Theme.Muted
    footer.BackgroundTransparency = 1
    footer.Size = UDim2.new(1, -171, 0, 14)
    footer.Position = UDim2.new(0, 163, 1, -18)
    footer.TextXAlignment = Enum.TextXAlignment.Right
    footer.Parent = win

    -- Drag
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
    UserInputService.InputChanged:Connect(function(inp)
        if draggingWin and (inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - dragStart
            win.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            draggingWin = false
        end
    end)

    print("[AxionHub] buildUI() finished.")
end

--=====================================================================
-- 🚀 BUILD
--=====================================================================
local ok, err = pcall(buildUI)
if not ok then
    warn("[AxionHub] buildUI ERROR:", err)
end

print("[AxionHub] v7 ready.")
