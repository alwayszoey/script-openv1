--[[
    AxionHub AutoDice v10
    Changelog v9 → v10:
      ✔ ลบ UIStroke ทุก card / ปุ่ม
      ✔ Toggle ไล่เฉดม่วง + เงาเฉียงจากซ้ายบน
      ✔ หน้าตาเรียบ minimal (ไม่มีกรอบ)
      ✔ แบ่ง Section ด้วยเส้นบางๆ แทนกรอบ
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

print("[AxionHub] ===== v10 starting =====")

--=====================================================================
-- THEME
--=====================================================================
local Theme = {
    Bg1      = Color3.fromRGB(14,  4,  26),
    Bg2      = Color3.fromRGB(6,   1,  12),
    Bg3      = Color3.fromRGB(0,   0,  0),

    Sidebar1 = Color3.fromRGB(52,  18, 92),
    Sidebar2 = Color3.fromRGB(20,  6,  40),

    -- Toggle gradient (ม่วงเข้ม → ม่วงสด)
    TogOffL  = Color3.fromRGB(28,  10, 50),
    TogOffR  = Color3.fromRGB(58,  22, 100),
    TogOnL   = Color3.fromRGB(90,  30, 180),
    TogOnR   = Color3.fromRGB(180, 100, 255),

    Accent   = Color3.fromRGB(168, 85, 247),
    Accent2  = Color3.fromRGB(124, 58, 237),
    AccentLt = Color3.fromRGB(222, 192, 255),

    Text     = Color3.fromRGB(248, 244, 255),
    TextDim  = Color3.fromRGB(180, 160, 210),
    Muted    = Color3.fromRGB(120, 100, 150),

    Divider  = Color3.fromRGB(50, 25, 85),

    Good     = Color3.fromRGB(130, 255, 180),
    Bad      = Color3.fromRGB(255, 100, 130),
    Gold     = Color3.fromRGB(255, 200, 80),
}

--=====================================================================
-- SAFE
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

local remotesReady = RollDice ~= nil and SetAutoRoll ~= nil
local collectReady = CollectBalance ~= nil

--=====================================================================
-- STATE
--=====================================================================
local State = {
    page         = "MAIN",
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

    minimized    = false,
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

LP.CharacterAdded:Connect(function()
    task.wait(2)
    if State.collectStarted and not State.autoCollect then
        startCollect()
    end
end)

--=====================================================================
-- 🎨 UI BUILDER — MINIMAL (NO BORDERS)
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
    blur.Name = "AxionHubBlur_Internal"
    blur.Size = 16
    blur.Parent = Lighting
    gui.Destroying:Connect(function()
        pcall(function() blur:Destroy() end)
    end)

    --=================================================================
    -- MINI MODE
    --=================================================================
    local miniBtn = Instance.new("TextButton")
    miniBtn.Size = UDim2.new(0, 48, 0, 48)
    miniBtn.Position = UDim2.new(0, 20, 0, 100)
    miniBtn.BackgroundColor3 = Theme.Sidebar1
    miniBtn.BackgroundTransparency = 0.1
    miniBtn.BorderSizePixel = 0
    miniBtn.Text = ""
    miniBtn.AutoButtonColor = false
    miniBtn.Visible = false
    miniBtn.Active = true
    miniBtn.Draggable = true
    miniBtn.Parent = gui
    Instance.new("UICorner", miniBtn).CornerRadius = UDim.new(0, 12)

    local mbGrad = Instance.new("UIGradient", miniBtn)
    mbGrad.Rotation = 90
    mbGrad.Color = ColorSequence.new(Theme.Sidebar1, Theme.Sidebar2)

    local mbIcon = Instance.new("TextLabel", miniBtn)
    mbIcon.Text = "◆"
    mbIcon.Font = Enum.Font.GothamBold
    mbIcon.TextSize = 22
    mbIcon.TextColor3 = Theme.AccentLt
    mbIcon.BackgroundTransparency = 1
    mbIcon.Size = UDim2.new(1, 0, 1, 0)

    --=================================================================
    -- WINDOW
    --=================================================================
    local win = Instance.new("Frame")
    win.Size = UDim2.new(0, 580, 0, 400)
    win.Position = UDim2.new(0.5, -290, 0.5, -200)
    win.BackgroundColor3 = Theme.Bg2
    win.BackgroundTransparency = 0.08
    win.BorderSizePixel = 0
    win.Active = true
    win.ClipsDescendants = true
    win.Parent = gui
    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 14)

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
        NumberSequenceKeypoint.new(1.0, 0.2),
    }

    -- ❌ ไม่มี UIStroke (ไม่มีกรอบ)

    --=================================================================
    -- SIDEBAR
    --=================================================================
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 155, 1, 0)
    sidebar.BackgroundColor3 = Theme.Sidebar1
    sidebar.BackgroundTransparency = 0.15
    sidebar.BorderSizePixel = 0
    sidebar.Parent = win
    Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 14)

    local sbGrad = Instance.new("UIGradient", sidebar)
    sbGrad.Rotation = 90
    sbGrad.Color = ColorSequence.new(Theme.Sidebar1, Theme.Sidebar2)
    sbGrad.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.05),
        NumberSequenceKeypoint.new(1, 0.35),
    }

    -- Glass highlight
    local sbHi = Instance.new("Frame", sidebar)
    sbHi.Size = UDim2.new(1, -2, 0, 1)
    sbHi.Position = UDim2.new(0, 1, 0, 1)
    sbHi.BackgroundColor3 = Color3.fromRGB(220, 180, 255)
    sbHi.BackgroundTransparency = 0.65
    sbHi.BorderSizePixel = 0

    -- Divider เส้นบาง
    local sbLine = Instance.new("Frame")
    sbLine.Size = UDim2.new(0, 1, 1, 0)
    sbLine.Position = UDim2.new(1, -1, 0, 0)
    sbLine.BackgroundColor3 = Theme.Divider
    sbLine.BackgroundTransparency = 0.5
    sbLine.BorderSizePixel = 0
    sbLine.Parent = sidebar

    -- Logo
    local logoBox = Instance.new("Frame")
    logoBox.Size = UDim2.new(0, 44, 0, 44)
    logoBox.Position = UDim2.new(0, 18, 0, 18)
    logoBox.BackgroundColor3 = Theme.Sidebar1
    logoBox.BackgroundTransparency = 0.3
    logoBox.BorderSizePixel = 0
    logoBox.Parent = sidebar
    Instance.new("UICorner", logoBox).CornerRadius = UDim.new(0, 12)

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
    sub.Text = "AutoDice  v10"
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
    divider.BackgroundColor3 = Theme.Divider
    divider.BackgroundTransparency = 0.4
    divider.BorderSizePixel = 0
    divider.Parent = sidebar

    --=================================================================
    -- ★ TOGGLE BUILDER — ม่วงไล่เฉด + เงาเฉียงซ้ายบน
    --=================================================================
    local function makeToggle(parent, y, label, defaultOn, cb)
        local lbl = Instance.new("TextLabel", parent)
        lbl.Text = label
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 11.5
        lbl.TextColor3 = Theme.Text
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(0.75, 0, 0, 24)
        lbl.Position = UDim2.new(0, 14, 0, y)
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        local pill = Instance.new("TextButton", parent)
        pill.Size = UDim2.new(0, 46, 0, 24)
        pill.Position = UDim2.new(1, -60, 0, y)
        pill.BackgroundColor3 = Color3.fromRGB(40, 15, 70)
        pill.Text = ""
        pill.AutoButtonColor = false
        Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

        -- ★ Gradient ม่วง ไล่ซ้าย-ขวา
        local grad = Instance.new("UIGradient", pill)
        grad.Rotation = 0
        grad.Color = defaultOn and ColorSequence.new{
            ColorSequenceKeypoint.new(0.0, Theme.TogOnL),
            ColorSequenceKeypoint.new(1.0, Theme.TogOnR),
        } or ColorSequence.new{
            ColorSequenceKeypoint.new(0.0, Theme.TogOffL),
            ColorSequenceKeypoint.new(1.0, Theme.TogOffR),
        }

        -- ★ เงาสีขาวเฉียงจากซ้ายบน (ไฮไลท์)
        local shine = Instance.new("Frame", pill)
        shine.Name = "Shine"
        shine.Size = UDim2.new(1, -4, 0.45, 0)
        shine.Position = UDim2.new(0, 2, 0, 1)
        shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        shine.BackgroundTransparency = defaultOn and 0.75 or 0.88
        shine.BorderSizePixel = 0
        shine.ZIndex = 2
        Instance.new("UICorner", shine).CornerRadius = UDim.new(1, 0)

        -- ★ เส้นเงาด้านล่าง (ให้ดูมีมิติ)
        local shadow = Instance.new("Frame", pill)
        shadow.Name = "Shadow"
        shadow.Size = UDim2.new(1, -4, 0.35, 0)
        shadow.Position = UDim2.new(0, 2, 1, -1)
        shadow.AnchorPoint = UDim2.new(0, 0, 1, 0)
        shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        shadow.BackgroundTransparency = 0.85
        shadow.BorderSizePixel = 0
        shadow.ZIndex = 1
        Instance.new("UICorner", shadow).CornerRadius = UDim.new(1, 0)

        -- ปุ่มกลม
        local k = Instance.new("Frame", pill)
        k.Size = UDim2.new(0, 18, 0, 18)
        k.Position = defaultOn and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        k.BackgroundColor3 = Color3.new(1,1,1)
        k.BorderSizePixel = 0
        k.ZIndex = 3
        Instance.new("UICorner", k).CornerRadius = UDim.new(1, 0)

        -- เงาของปุ่มกลม
        local kShine = Instance.new("Frame", k)
        kShine.Size = UDim2.new(0.8, 0, 0.4, 0)
        kShine.Position = UDim2.new(0.1, 0, 0.05, 0)
        kShine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        kShine.BackgroundTransparency = 0.2
        kShine.BorderSizePixel = 0
        Instance.new("UICorner", kShine).CornerRadius = UDim.new(1, 0)

        local on = defaultOn
        local function update()
            grad.Color = on and ColorSequence.new{
                ColorSequenceKeypoint.new(0.0, Theme.TogOnL),
                ColorSequenceKeypoint.new(1.0, Theme.TogOnR),
            } or ColorSequence.new{
                ColorSequenceKeypoint.new(0.0, Theme.TogOffL),
                ColorSequenceKeypoint.new(1.0, Theme.TogOffR),
            }
            TweenService:Create(shine, TweenInfo.new(0.22), {
                BackgroundTransparency = on and 0.75 or 0.88
            }):Play()
            TweenService:Create(k, TweenInfo.new(0.22), {
                Position = on and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
            }):Play()
        end

        pill.MouseButton1Click:Connect(function()
            on = not on
            update()
            if cb then cb(on) end
        end)

        return { Set = function(v) on = v; update() end }
    end

    --=================================================================
    -- SIDEBAR MENU
    --=================================================================
    local pages = { "MAIN", "SETTINGS" }
    local pageIcons = { "🏠", "⚙" }
    local pageDesc = {
        ["MAIN"]     = "dice & collect",
        ["SETTINGS"] = "animation / range",
    }

    local pageBtns = {}
    local yBase = 132
    for i, p in ipairs(pages) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -24, 0, 44)
        btn.Position = UDim2.new(0, 12, 0, yBase + (i-1) * 50)
        btn.BackgroundColor3 = Color3.fromRGB(30, 10, 55)
        btn.BackgroundTransparency = 0.65
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.Parent = sidebar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

        -- ❌ ไม่มี UIStroke

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
        badge.BackgroundColor3 = Theme.Sidebar1
        badge.BackgroundTransparency = 0.3
        badge.BorderSizePixel = 0
        Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 8)

        local icon = Instance.new("TextLabel", badge)
        icon.Text = pageIcons[i]
        icon.Font = Enum.Font.GothamBold
        icon.TextSize = 14
        icon.TextColor3 = Theme.AccentLt
        icon.BackgroundTransparency = 1
        icon.Size = UDim2.new(1, 0, 1, 0)

        local nameLbl = Instance.new("TextLabel", btn)
        nameLbl.Text = p:sub(1,1) .. p:sub(2):lower()
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 11.5
        nameLbl.TextColor3 = Theme.TextDim
        nameLbl.BackgroundTransparency = 1
        nameLbl.Size = UDim2.new(1, -50, 0, 14)
        nameLbl.Position = UDim2.new(0, 44, 0, 7)
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left

        local descLbl = Instance.new("TextLabel", btn)
        descLbl.Text = pageDesc[p]
        descLbl.Font = Enum.Font.Gotham
        descLbl.TextSize = 9
        descLbl.TextColor3 = Theme.Muted
        descLbl.BackgroundTransparency = 1
        descLbl.Size = UDim2.new(1, -50, 0, 12)
        descLbl.Position = UDim2.new(0, 44, 0, 23)
        descLbl.TextXAlignment = Enum.TextXAlignment.Left

        pageBtns[p] = { btn=btn, glow=glow, name=nameLbl, icon=icon }

        btn.MouseEnter:Connect(function()
            if State.page ~= p then
                TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundTransparency = 0.4 }):Play()
                TweenService:Create(nameLbl, TweenInfo.new(0.15), { TextColor3 = Theme.Text }):Play()
            end
        end)
        btn.MouseLeave:Connect(function()
            if State.page ~= p then
                TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundTransparency = 0.65 }):Play()
                TweenService:Create(nameLbl, TweenInfo.new(0.15), { TextColor3 = Theme.TextDim }):Play()
            end
        end)
    end

    --=================================================================
    -- CONTENT
    --=================================================================
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -155, 1, 0)
    content.Position = UDim2.new(0, 155, 0, 0)
    content.BackgroundTransparency = 1
    content.Parent = win

    --=================================================================
    -- MAIN PAGE
    --=================================================================
    local mainPage = Instance.new("Frame")
    mainPage.Size = UDim2.new(1, 0, 1, 0)
    mainPage.BackgroundTransparency = 1
    mainPage.Parent = content

    -- Section header (สถานะ)
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, -36, 0, 40)
    header.Position = UDim2.new(0, 18, 0, 16)
    header.BackgroundTransparency = 1
    header.Parent = mainPage

    local dot = Instance.new("Frame", header)
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.Position = UDim2.new(0, 4, 0.5, -4)
    dot.BackgroundColor3 = Theme.Muted
    dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local statusTxt = Instance.new("TextLabel", header)
    statusTxt.Font = Enum.Font.Gotham
    statusTxt.TextSize = 11
    statusTxt.TextColor3 = Theme.TextDim
    statusTxt.BackgroundTransparency = 1
    statusTxt.Size = UDim2.new(1, -20, 1, 0)
    statusTxt.Position = UDim2.new(0, 20, 0, 0)
    statusTxt.TextXAlignment = Enum.TextXAlignment.Left
    statusTxt.Text = "READY"

    task.spawn(function()
        while statusTxt.Parent do
            local ready = remotesReady
            local stat = ready and (State.running and "RUNNING" or "IDLE") or "NO REMOTES"
            local color = ready and (State.running and Theme.Good or Theme.Muted) or Theme.Bad
            statusTxt.Text = string.format("%s · rolls: %d · 💰 %d",
                stat, State.rolls, State.collected)
            dot.BackgroundColor3 = color
            task.wait(0.2)
        end
    end)

    -- ★ เส้นแบ่ง
    local function makeDivider(parent, y)
        local d = Instance.new("Frame", parent)
        d.Size = UDim2.new(1, -36, 0, 1)
        d.Position = UDim2.new(0, 18, 0, y)
        d.BackgroundColor3 = Theme.Divider
        d.BackgroundTransparency = 0.4
        d.BorderSizePixel = 0
        return d
    end

    -- Section: MODE
    local modeLbl = Instance.new("TextLabel", mainPage)
    modeLbl.Text = "MODE"
    modeLbl.Font = Enum.Font.GothamBold
    modeLbl.TextSize = 10
    modeLbl.TextColor3 = Theme.Muted
    modeLbl.BackgroundTransparency = 1
    modeLbl.Size = UDim2.new(1, -36, 0, 14)
    modeLbl.Position = UDim2.new(0, 20, 0, 68)
    modeLbl.TextXAlignment = Enum.TextXAlignment.Left

    local modes = {"AUTO", "SPAM", "BOTH"}
    local modeBtns = {}
    for i, m in ipairs(modes) do
        local mb = Instance.new("TextButton")
        mb.Size = UDim2.new(0, 82, 0, 28)
        mb.Position = UDim2.new(0, 20 + (i-1) * 88, 0, 90)
        mb.BackgroundColor3 = Color3.fromRGB(40, 15, 70)
        mb.BackgroundTransparency = 0.4
        mb.BorderSizePixel = 0
        mb.Text = m
        mb.Font = Enum.Font.GothamBold
        mb.TextSize = 11
        mb.TextColor3 = Theme.TextDim
        mb.AutoButtonColor = false
        mb.Parent = mainPage
        Instance.new("UICorner", mb).CornerRadius = UDim.new(0, 8)

        -- ❌ ไม่มี stroke

        -- Highlight เฉียงซ้ายบน
        local mbShine = Instance.new("Frame", mb)
        mbShine.Size = UDim2.new(1, -4, 0.4, 0)
        mbShine.Position = UDim2.new(0, 2, 0, 1)
        mbShine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        mbShine.BackgroundTransparency = 0.9
        mbShine.BorderSizePixel = 0
        mbShine.ZIndex = 2
        Instance.new("UICorner", mbShine).CornerRadius = UDim.new(1, 0)

        modeBtns[m] = { btn = mb, shine = mbShine }

        mb.MouseButton1Click:Connect(function()
            State.mode = m
            for mm, data in pairs(modeBtns) do
                local on = (mm == State.mode)
                data.btn.BackgroundTransparency = on and 0.15 or 0.4
                data.btn.TextColor3 = on and Theme.Text or Theme.TextDim
                TweenService:Create(data.btn, TweenInfo.new(0.15), {
                    BackgroundColor3 = on and Theme.Accent or Color3.fromRGB(40, 15, 70),
                }):Play()
            end
        end)
    end

    -- init
    for mm, data in pairs(modeBtns) do
        local on = (mm == State.mode)
        data.btn.BackgroundTransparency = on and 0.15 or 0.4
        data.btn.TextColor3 = on and Theme.Text or Theme.TextDim
        data.btn.BackgroundColor3 = on and Theme.Accent or Color3.fromRGB(40, 15, 70)
    end

    makeDivider(mainPage, 134)

    -- Section: SPAM SPEED
    local spdLbl = Instance.new("TextLabel", mainPage)
    spdLbl.Text = "SPAM SPEED"
    spdLbl.Font = Enum.Font.GothamBold
    spdLbl.TextSize = 10
    spdLbl.TextColor3 = Theme.Muted
    spdLbl.BackgroundTransparency = 1
    spdLbl.Size = UDim2.new(0.5, 0, 0, 14)
    spdLbl.Position = UDim2.new(0, 20, 0, 148)
    spdLbl.TextXAlignment = Enum.TextXAlignment.Left

    local spdVal = Instance.new("TextLabel", mainPage)
    spdVal.Text = "33 / sec"
    spdVal.Font = Enum.Font.GothamBold
    spdVal.TextSize = 11
    spdVal.TextColor3 = Theme.Text
    spdVal.BackgroundTransparency = 1
    spdVal.Size = UDim2.new(0.5, -20, 0, 14)
    spdVal.Position = UDim2.new(0.5, 0, 0, 148)
    spdVal.TextXAlignment = Enum.TextXAlignment.Right

    -- Slider
    local track = Instance.new("TextButton", mainPage)
    track.Size = UDim2.new(1, -40, 0, 6)
    track.Position = UDim2.new(0, 20, 0, 172)
    track.BackgroundColor3 = Color3.fromRGB(30, 12, 55)
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
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = false
        end
    end)

    makeDivider(mainPage, 200)

    -- Toggle: AFK Collect
    makeToggle(mainPage, 214, "💰 AFK Collect Money",
        State.autoCollect,
        function(v)
            if v then startCollect() else stopCollect() end
        end)

    local acInfo = Instance.new("TextLabel", mainPage)
    acInfo.Text = string.format("every %.1fs · plot %d→%d",
        State.collectRate, State.plotMin, State.plotMax)
    acInfo.Font = Enum.Font.Gotham
    acInfo.TextSize = 9.5
    acInfo.TextColor3 = Theme.Muted
    acInfo.BackgroundTransparency = 1
    acInfo.Size = UDim2.new(1, -40, 0, 14)
    acInfo.Position = UDim2.new(0, 22, 0, 242)
    acInfo.TextXAlignment = Enum.TextXAlignment.Left

    makeDivider(mainPage, 264)

    -- Toggle: Auto Roll
    makeToggle(mainPage, 278, "🎲 Auto Roll",
        State.running,
        function(v)
            if v then start() else stop() end
        end)

    local arInfo = Instance.new("TextLabel", mainPage)
    arInfo.Text = "click toggle to start rolling"
    arInfo.Font = Enum.Font.Gotham
    arInfo.TextSize = 9.5
    arInfo.TextColor3 = Theme.Muted
    arInfo.BackgroundTransparency = 1
    arInfo.Size = UDim2.new(1, -40, 0, 14)
    arInfo.Position = UDim2.new(0, 22, 0, 306)
    arInfo.TextXAlignment = Enum.TextXAlignment.Left

    --=================================================================
    -- SETTINGS PAGE
    --=================================================================
    local settingsPage = Instance.new("Frame")
    settingsPage.Size = UDim2.new(1, 0, 1, 0)
    settingsPage.BackgroundTransparency = 1
    settingsPage.Visible = false
    settingsPage.Parent = content

    local sTitle = Instance.new("TextLabel", settingsPage)
    sTitle.Text = "SETTINGS"
    sTitle.Font = Enum.Font.GothamBold
    sTitle.TextSize = 11
    sTitle.TextColor3 = Theme.Muted
    sTitle.BackgroundTransparency = 1
    sTitle.Size = UDim2.new(1, -36, 0, 14)
    sTitle.Position = UDim2.new(0, 20, 0, 24)
    sTitle.TextXAlignment = Enum.TextXAlignment.Left

    makeToggle(settingsPage, 52, "Bypass Roll Animation",
        State.bypassAnim,
        function(v) State.bypassAnim = v end)

    local div2 = Instance.new("Frame", settingsPage)
    div2.Size = UDim2.new(1, -36, 0, 1)
    div2.Position = UDim2.new(0, 18, 0, 90)
    div2.BackgroundColor3 = Theme.Divider
    div2.BackgroundTransparency = 0.4
    div2.BorderSizePixel = 0

    makeToggle(settingsPage, 104, "Kill Camera Cutscene",
        State.killCutscene,
        function(v) State.killCutscene = v end)

    local div3 = Instance.new("Frame", settingsPage)
    div3.Size = UDim2.new(1, -36, 0, 1)
    div3.Position = UDim2.new(0, 18, 0, 142)
    div3.BackgroundColor3 = Theme.Divider
    div3.BackgroundTransparency = 0.4
    div3.BorderSizePixel = 0

    -- Plot range
    local rcLbl = Instance.new("TextLabel", settingsPage)
    rcLbl.Text = "PLOT RANGE"
    rcLbl.Font = Enum.Font.GothamBold
    rcLbl.TextSize = 10
    rcLbl.TextColor3 = Theme.Muted
    rcLbl.BackgroundTransparency = 1
    rcLbl.Size = UDim2.new(1, -40, 0, 14)
    rcLbl.Position = UDim2.new(0, 20, 0, 158)
    rcLbl.TextXAlignment = Enum.TextXAlignment.Left

    local rcVal = Instance.new("TextLabel", settingsPage)
    rcVal.Text = string.format("1 → %d", State.plotMax)
    rcVal.Font = Enum.Font.Gotham
    rcVal.TextSize = 10
    rcVal.TextColor3 = Theme.TextDim
    rcVal.BackgroundTransparency = 1
    rcVal.Size = UDim2.new(1, -40, 0, 14)
    rcVal.Position = UDim2.new(0, 20, 0, 176)
    rcVal.TextXAlignment = Enum.TextXAlignment.Left

    local function rangeBtn(txt, xPos, val)
        local b = Instance.new("TextButton", settingsPage)
        b.Size = UDim2.new(0, 70, 0, 28)
        b.Position = UDim2.new(0, xPos, 0, 200)
        b.BackgroundColor3 = Color3.fromRGB(40, 15, 70)
        b.BackgroundTransparency = 0.3
        b.Text = txt
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.TextColor3 = Theme.Text
        b.AutoButtonColor = false
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)

        -- Shine
        local sh = Instance.new("Frame", b)
        sh.Size = UDim2.new(1, -4, 0.4, 0)
        sh.Position = UDim2.new(0, 2, 0, 1)
        sh.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        sh.BackgroundTransparency = 0.88
        sh.BorderSizePixel = 0
        sh.ZIndex = 2
        Instance.new("UICorner", sh).CornerRadius = UDim.new(1, 0)

        b.MouseButton1Click:Connect(function()
            State.plotMin, State.plotMax = 1, val
            rcVal.Text = string.format("1 → %d", State.plotMax)
            acInfo.Text = string.format("every %.1fs · plot %d→%d",
                State.collectRate, State.plotMin, State.plotMax)
        end)
        return b
    end

    rangeBtn("1 → 4", 20, 4)
    rangeBtn("1 → 8", 100, 8)
    rangeBtn("1 → 16", 180, 16)

    --=================================================================
    -- PAGE SWITCHER
    --=================================================================
    local function applyPage()
        for p, data in pairs(pageBtns) do
            local on = (p == State.page)
            data.glow.Visible = on
            data.name.TextColor3 = on and Theme.Text or Theme.TextDim
            data.icon.TextColor3 = on and Theme.Text or Theme.AccentLt
            data.btn.BackgroundTransparency = on and 0.15 or 0.65
            data.btn.BackgroundColor3 = on and Theme.Sidebar1 or Color3.fromRGB(30, 10, 55)
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

    --=================================================================
    -- ปุ่มมุมขวาบน
    --=================================================================
    local topBtnsFrame = Instance.new("Frame")
    topBtnsFrame.Size = UDim2.new(0, 60, 0, 22)
    topBtnsFrame.Position = UDim2.new(1, -70, 0, 10)
    topBtnsFrame.BackgroundTransparency = 1
    topBtnsFrame.Parent = win

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 22, 0, 22)
    minBtn.Position = UDim2.new(0, 0, 0, 0)
    minBtn.BackgroundColor3 = Color3.fromRGB(40, 15, 70)
    minBtn.BackgroundTransparency = 0.3
    minBtn.BorderSizePixel = 0
    minBtn.Text = "—"
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 14
    minBtn.TextColor3 = Theme.Text
    minBtn.AutoButtonColor = false
    minBtn.Parent = topBtnsFrame
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(1, 0)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(0, 32, 0, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(60, 15, 25)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.TextColor3 = Theme.Text
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = topBtnsFrame
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)

    minBtn.MouseEnter:Connect(function()
        TweenService:Create(minBtn, TweenInfo.new(0.15), {BackgroundTransparency=0.1}):Play()
    end)
    minBtn.MouseLeave:Connect(function()
        TweenService:Create(minBtn, TweenInfo.new(0.15), {BackgroundTransparency=0.3}):Play()
    end)
    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundTransparency=0.05}):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundTransparency=0.2}):Play()
    end)

    minBtn.MouseButton1Click:Connect(function()
        State.minimized = true
        win.Visible = false
        miniBtn.Visible = true
        if blur then blur.Size = 0 end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        pcall(stop)
        pcall(stopCollect)
        pcall(function() blur:Destroy() end)
        pcall(function() gui:Destroy() end)
        print("[AxionHub] Script closed by user.")
    end)

    miniBtn.MouseButton1Click:Connect(function()
        State.minimized = false
        win.Visible = true
        miniBtn.Visible = false
        if blur then blur.Size = 16 end
    end)

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

    applyPage()
    print("[AxionHub] buildUI() finished.")
end

--=====================================================================
-- 🚀 BUILD
--=====================================================================
local ok, err = pcall(buildUI)
if not ok then
    warn("[AxionHub] buildUI ERROR:", err)
end

print("[AxionHub] v10 ready.")
