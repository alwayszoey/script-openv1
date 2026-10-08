--[[
    AxionHub AutoDice v11
    Changelog v10 → v11:
      ✔ ลบเงาขาวออกจาก Card (เหลือแค่ที่ toggle)
      ✔ Content bg โปร่งใสขึ้น + blur นุ่ม
      ✔ รวม MODE + Auto Roll เป็นการ์ดเดียว
      ✔ Card gradient ม่วงดำล้วน ไม่มี highlight ทับ
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

print("[AxionHub] ===== v11 starting =====")

--=====================================================================
-- THEME
--=====================================================================
local Theme = {
    Bg1      = Color3.fromRGB(14,  4,  26),
    Bg2      = Color3.fromRGB(7,   2,  14),
    Bg3      = Color3.fromRGB(0,   0,  0),

    Card1    = Color3.fromRGB(72,  28, 118),
    Card2    = Color3.fromRGB(42,  14, 80),
    Card3    = Color3.fromRGB(18,  4,  36),

    Sidebar1 = Color3.fromRGB(62,  24, 108),
    Sidebar2 = Color3.fromRGB(34,  12, 62),

    TogOffL  = Color3.fromRGB(14,  4,  24),
    TogOffR  = Color3.fromRGB(50,  20, 84),
    TogOnL   = Color3.fromRGB(28,  6,  50),
    TogOnR   = Color3.fromRGB(168, 85, 247),

    Accent   = Color3.fromRGB(168, 85, 247),
    Accent2  = Color3.fromRGB(124, 58, 237),
    AccentLt = Color3.fromRGB(222, 192, 255),

    Text     = Color3.fromRGB(248, 244, 255),
    TextDim  = Color3.fromRGB(200, 180, 235),
    Muted    = Color3.fromRGB(150, 128, 190),

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

print("[AxionHub] RollDice       =", RollDice)
print("[AxionHub] SetAutoRoll    =", SetAutoRoll)
print("[AxionHub] CollectBalance =", CollectBalance)

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
    print("[AxionHub] 💰 collect started")
    while State.autoCollect do
        for plotNum = State.plotMin, State.plotMax do
            if not State.autoCollect then break end
            collectOnePlot(plotNum)
            task.wait(0.04)
        end
        task.wait(State.collectRate)
    end
    print("[AxionHub] 💰 collect stopped")
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
-- 🎨 UI BUILDER
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

    -- ★ Blur นุ่มกว่าเดิม (เบลอนิดๆ)
    local blur = Instance.new("BlurEffect")
    blur.Name = "AxionHubBlur_Internal"
    blur.Size = 10
    blur.Parent = Lighting
    gui.Destroying:Connect(function()
        pcall(function() blur:Destroy() end)
    end)

    --=================================================================
    -- ★ HELPER: card ม่วงดำล้วน (ไม่มีเงาขาวทับ)
    --=================================================================
    local function makeCard(parent, size, pos)
        local card = Instance.new("Frame")
        card.Size = size
        card.Position = pos
        card.BackgroundColor3 = Color3.fromRGB(20, 6, 38)
        card.BackgroundTransparency = 0.25      -- ★ โปร่งใสขึ้น
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
            NumberSequenceKeypoint.new(0.0, 0.15),
            NumberSequenceKeypoint.new(1.0, 0.55),
        }
        return card
    end

    --=================================================================
    -- ★ HELPER: Toggle (ม่วงไล่เฉด + เงาขาว) — มีแค่ตรงนี้
    --=================================================================
    local function makeToggle(parent, y, label, defaultOn, cb, sizeW, sizeH, posX)
        sizeW = sizeW or 46
        sizeH = sizeH or 24
        posX = posX or UDim2.new(1, -60, 0, y)

        local lbl = Instance.new("TextLabel", parent)
        lbl.Text = label
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 11.5
        lbl.TextColor3 = Theme.Text
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(0.75, 0, 0, 20)
        lbl.Position = UDim2.new(0, 14, 0, y)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 4

        local pill = Instance.new("TextButton", parent)
        pill.Size = UDim2.new(0, sizeW, 0, sizeH)
        pill.Position = posX
        pill.BackgroundColor3 = Color3.fromRGB(10, 3, 20)
        pill.Text = ""
        pill.AutoButtonColor = false
        pill.ZIndex = 4
        Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

        -- Gradient ม่วงไล่เฉด
        local grad = Instance.new("UIGradient", pill)
        grad.Rotation = 0
        grad.Color = defaultOn and ColorSequence.new{
            ColorSequenceKeypoint.new(0.0, Theme.TogOnL),
            ColorSequenceKeypoint.new(1.0, Theme.TogOnR),
        } or ColorSequence.new{
            ColorSequenceKeypoint.new(0.0, Theme.TogOffL),
            ColorSequenceKeypoint.new(1.0, Theme.TogOffR),
        }

        -- ★ เงาขาวเฉียง (เฉพาะ toggle)
        local tgHi = Instance.new("Frame", pill)
        tgHi.Name = "TopLeftHighlight"
        tgHi.Size = UDim2.new(0.6, 0, 0.6, 0)
        tgHi.Position = UDim2.new(0, 0, 0, 0)
        tgHi.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        tgHi.BackgroundTransparency = 0.55
        tgHi.BorderSizePixel = 0
        tgHi.ZIndex = 1

        local tgGrad = Instance.new("UIGradient", tgHi)
        tgGrad.Rotation = 135
        tgGrad.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0.0, 0.35),
            NumberSequenceKeypoint.new(0.7, 1.0),
            NumberSequenceKeypoint.new(1.0, 1.0),
        }
        Instance.new("UICorner", tgHi).CornerRadius = UDim.new(1, 0)

        -- Knob
        local k = Instance.new("Frame", pill)
        k.Size = UDim2.new(0, sizeH - 6, 0, sizeH - 6)
        k.Position = defaultOn and UDim2.new(1, -(sizeH-3), 0.5, -(sizeH-6)/2) or UDim2.new(0, 3, 0.5, -(sizeH-6)/2)
        k.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        k.BorderSizePixel = 0
        k.ZIndex = 5
        Instance.new("UICorner", k).CornerRadius = UDim.new(1, 0)

        local on = defaultOn
        local function update()
            grad.Color = on and ColorSequence.new{
                ColorSequenceKeypoint.new(0.0, Theme.TogOnL),
                ColorSequenceKeypoint.new(1.0, Theme.TogOnR),
            } or ColorSequence.new{
                ColorSequenceKeypoint.new(0.0, Theme.TogOffL),
                ColorSequenceKeypoint.new(1.0, Theme.TogOffR),
            }
            TweenService:Create(k, TweenInfo.new(0.22), {
                Position = on and UDim2.new(1, -(sizeH-3), 0.5, -(sizeH-6)/2)
                            or UDim2.new(0, 3, 0.5, -(sizeH-6)/2)
            }):Play()
        end

        pill.MouseButton1Click:Connect(function()
            on = not on
            update()
            if cb then cb(on) end
        end)

        return { Set = function(v)
            on = v
            update()
        end }
    end

    --=================================================================
    -- MINI MODE
    --=================================================================
    local miniBtn = Instance.new("TextButton")
    miniBtn.Name = "MiniBtn"
    miniBtn.Size = UDim2.new(0, 48, 0, 48)
    miniBtn.Position = UDim2.new(0, 20, 0, 100)
    miniBtn.BackgroundColor3 = Theme.Card2
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
    mbGrad.Color = ColorSequence.new(Theme.Card1, Theme.Card3)

    local mbIcon = Instance.new("TextLabel", miniBtn)
    mbIcon.Text = "◆"
    mbIcon.Font = Enum.Font.GothamBold
    mbIcon.TextSize = 22
    mbIcon.TextColor3 = Theme.AccentLt
    mbIcon.BackgroundTransparency = 1
    mbIcon.Size = UDim2.new(1, 0, 1, 0)
    mbIcon.ZIndex = 3

    --=================================================================
    -- WINDOW (★ โปร่งใสขึ้น)
    --=================================================================
    local win = Instance.new("Frame")
    win.Name = "Window"
    win.Size = UDim2.new(0, 580, 0, 400)
    win.Position = UDim2.new(0.5, -290, 0.5, -200)
    win.BackgroundColor3 = Theme.Bg2
    win.BackgroundTransparency = 0.35       -- ★ โปร่งใสขึ้น
    win.BorderSizePixel = 0
    win.Active = true
    win.ClipsDescendants = true
    win.Parent = gui
    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 16)

    local winGrad = Instance.new("UIGradient", win)
    winGrad.Rotation = 90
    winGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0.00, Theme.Bg1),
        ColorSequenceKeypoint.new(0.45, Theme.Bg2),
        ColorSequenceKeypoint.new(1.00, Theme.Bg3),
    }

    --=================================================================
    -- SIDEBAR
    --=================================================================
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 155, 1, 0)
    sidebar.BackgroundColor3 = Theme.Sidebar1
    sidebar.BackgroundTransparency = 0.25
    sidebar.BorderSizePixel = 0
    sidebar.Parent = win
    Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 16)

    local sbGrad = Instance.new("UIGradient", sidebar)
    sbGrad.Rotation = 90
    sbGrad.Color = ColorSequence.new(Theme.Sidebar1, Theme.Sidebar2)

    -- Logo
    local logoBox = Instance.new("Frame")
    logoBox.Size = UDim2.new(0, 44, 0, 44)
    logoBox.Position = UDim2.new(0, 18, 0, 18)
    logoBox.BackgroundColor3 = Theme.Card2
    logoBox.BorderSizePixel = 0
    logoBox.ZIndex = 3
    logoBox.Parent = sidebar
    Instance.new("UICorner", logoBox).CornerRadius = UDim.new(0, 12)

    local lgGrad = Instance.new("UIGradient", logoBox)
    lgGrad.Rotation = 135
    lgGrad.Color = ColorSequence.new(Theme.Card1, Theme.Card3)

    local logoIcon = Instance.new("TextLabel")
    logoIcon.Text = "◆"
    logoIcon.Font = Enum.Font.GothamBold
    logoIcon.TextSize = 22
    logoIcon.TextColor3 = Theme.AccentLt
    logoIcon.BackgroundTransparency = 1
    logoIcon.Size = UDim2.new(1, 0, 1, 0)
    logoIcon.ZIndex = 4
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
    title.ZIndex = 3
    title.Parent = sidebar

    local sub = Instance.new("TextLabel")
    sub.Text = "AutoDice  v11"
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 10
    sub.TextColor3 = Theme.Muted
    sub.BackgroundTransparency = 1
    sub.Size = UDim2.new(1, -20, 0, 14)
    sub.Position = UDim2.new(0, 18, 0, 88)
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.ZIndex = 3
    sub.Parent = sidebar

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, -32, 0, 1)
    divider.Position = UDim2.new(0, 16, 0, 118)
    divider.BackgroundColor3 = Color3.fromRGB(120, 60, 200)
    divider.BackgroundTransparency = 0.65
    divider.BorderSizePixel = 0
    divider.ZIndex = 3
    divider.Parent = sidebar

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
        btn.BackgroundColor3 = Theme.Card2
        btn.BackgroundTransparency = 0.7
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.ZIndex = 3
        btn.Parent = sidebar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

        local glow = Instance.new("Frame", btn)
        glow.Size = UDim2.new(1, 0, 1, 0)
        glow.BackgroundColor3 = Theme.Accent
        glow.BackgroundTransparency = 0.85
        glow.BorderSizePixel = 0
        glow.Visible = false
        glow.ZIndex = 1
        Instance.new("UICorner", glow).CornerRadius = UDim.new(0, 10)

        local badge = Instance.new("Frame", btn)
        badge.Size = UDim2.new(0, 28, 0, 28)
        badge.Position = UDim2.new(0, 8, 0.5, -14)
        badge.BackgroundColor3 = Theme.Card1
        badge.BorderSizePixel = 0
        badge.ZIndex = 4
        Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 8)

        local icon = Instance.new("TextLabel", badge)
        icon.Text = pageIcons[i]
        icon.Font = Enum.Font.GothamBold
        icon.TextSize = 14
        icon.TextColor3 = Theme.AccentLt
        icon.BackgroundTransparency = 1
        icon.Size = UDim2.new(1, 0, 1, 0)
        icon.ZIndex = 5

        local nameLbl = Instance.new("TextLabel", btn)
        nameLbl.Text = p:sub(1,1) .. p:sub(2):lower()
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 11.5
        nameLbl.TextColor3 = Theme.TextDim
        nameLbl.BackgroundTransparency = 1
        nameLbl.Size = UDim2.new(1, -50, 0, 14)
        nameLbl.Position = UDim2.new(0, 44, 0, 7)
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.ZIndex = 4

        local descLbl = Instance.new("TextLabel", btn)
        descLbl.Text = pageDesc[p]
        descLbl.Font = Enum.Font.Gotham
        descLbl.TextSize = 9
        descLbl.TextColor3 = Theme.Muted
        descLbl.BackgroundTransparency = 1
        descLbl.Size = UDim2.new(1, -50, 0, 12)
        descLbl.Position = UDim2.new(0, 44, 0, 23)
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.ZIndex = 4

        pageBtns[p] = { btn=btn, glow=glow, name=nameLbl, icon=icon }
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

    -- Header
    local header = makeCard(mainPage, UDim2.new(1, -36, 0, 46), UDim2.new(0, 18, 0, 16))

    local dot = Instance.new("Frame", header)
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.Position = UDim2.new(0, 14, 0.5, -4)
    dot.BackgroundColor3 = Theme.Muted
    dot.BorderSizePixel = 0
    dot.ZIndex = 4
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local statusTxt = Instance.new("TextLabel", header)
    statusTxt.Font = Enum.Font.Gotham
    statusTxt.TextSize = 11
    statusTxt.TextColor3 = Theme.Text
    statusTxt.BackgroundTransparency = 1
    statusTxt.Size = UDim2.new(1, -90, 1, 0)
    statusTxt.Position = UDim2.new(0, 30, 0, 0)
    statusTxt.TextXAlignment = Enum.TextXAlignment.Left
    statusTxt.Text = "READY"
    statusTxt.ZIndex = 4

    task.spawn(function()
        while statusTxt.Parent do
            local ready = remotesReady
            local stat = ready and (State.running and "RUNNING" or "IDLE") or "NO REMOTES"
            local color = ready and (State.running and Theme.Good or Theme.Muted) or Theme.Bad
            statusTxt.Text = string.format("💤 · %s · rolls: %d · 💰 %d",
                stat, State.rolls, State.collected)
            dot.BackgroundColor3 = color
            task.wait(0.2)
        end
    end)

    --=================================================================
    -- ★★★ MODE + AUTO ROLL รวมเป็น card เดียว ★★★
    --=================================================================
    local modeCard = makeCard(mainPage, UDim2.new(1, -36, 0, 106), UDim2.new(0, 18, 0, 76))

    local mcLbl = Instance.new("TextLabel", modeCard)
    mcLbl.Text = "MODE"
    mcLbl.Font = Enum.Font.GothamBold
    mcLbl.TextSize = 9.5
    mcLbl.TextColor3 = Theme.AccentLt
    mcLbl.BackgroundTransparency = 1
    mcLbl.Size = UDim2.new(1, -28, 0, 14)
    mcLbl.Position = UDim2.new(0, 14, 0, 8)
    mcLbl.TextXAlignment = Enum.TextXAlignment.Left
    mcLbl.ZIndex = 4

    -- ปุ่มโหมด 3 ปุ่ม (AUTO / SPAM / BOTH)
    local modes = {"AUTO", "SPAM", "BOTH"}
    local modeBtns = {}
    for i, m in ipairs(modes) do
        local mb = Instance.new("TextButton")
        mb.Size = UDim2.new(0, 82, 0, 30)
        mb.Position = UDim2.new(0, 14 + (i-1) * 88, 0, 28)
        mb.BackgroundColor3 = Color3.fromRGB(16, 4, 32)
        mb.BackgroundTransparency = 0.4
        mb.BorderSizePixel = 0
        mb.Text = m
        mb.Font = Enum.Font.GothamBold
        mb.TextSize = 11
        mb.TextColor3 = Theme.TextDim
        mb.AutoButtonColor = false
        mb.ZIndex = 4
        mb.Parent = modeCard
        Instance.new("UICorner", mb).CornerRadius = UDim.new(0, 8)

        modeBtns[m] = { btn = mb }

        mb.MouseButton1Click:Connect(function()
            State.mode = m
            for mm, data in pairs(modeBtns) do
                local on = (mm == State.mode)
                data.btn.BackgroundColor3 = on and Theme.Accent or Color3.fromRGB(16, 4, 32)
                data.btn.BackgroundTransparency = on and 0.2 or 0.4
                data.btn.TextColor3 = on and Theme.Text or Theme.TextDim
            end
        end)
    end

    for mm, data in pairs(modeBtns) do
        local on = (mm == State.mode)
        data.btn.BackgroundColor3 = on and Theme.Accent or Color3.fromRGB(16, 4, 32)
        data.btn.BackgroundTransparency = on and 0.2 or 0.4
        data.btn.TextColor3 = on and Theme.Text or Theme.TextDim
    end

    -- Divider ใน card
    local innerDiv = Instance.new("Frame", modeCard)
    innerDiv.Size = UDim2.new(1, -28, 0, 1)
    innerDiv.Position = UDim2.new(0, 14, 0, 66)
    innerDiv.BackgroundColor3 = Color3.fromRGB(120, 60, 200)
    innerDiv.BackgroundTransparency = 0.7
    innerDiv.BorderSizePixel = 0
    innerDiv.ZIndex = 4

    -- 🎲 Auto Roll toggle ใน card เดียวกัน
    local arLbl = Instance.new("TextLabel", modeCard)
    arLbl.Text = "🎲 Auto Roll"
    arLbl.Font = Enum.Font.GothamBold
    arLbl.TextSize = 12
    arLbl.TextColor3 = Theme.Text
    arLbl.BackgroundTransparency = 1
    arLbl.Size = UDim2.new(0.6, 0, 0, 20)
    arLbl.Position = UDim2.new(0, 14, 0, 76)
    arLbl.TextXAlignment = Enum.TextXAlignment.Left
    arLbl.ZIndex = 4

    local arInfo = Instance.new("TextLabel", modeCard)
    arInfo.Text = "click to start rolling"
    arInfo.Font = Enum.Font.Gotham
    arInfo.TextSize = 9
    arInfo.TextColor3 = Theme.AccentLt
    arInfo.BackgroundTransparency = 1
    arInfo.Size = UDim2.new(1, -100, 0, 12)
    arInfo.Position = UDim2.new(0, 14, 0, 92)
    arInfo.TextXAlignment = Enum.TextXAlignment.Left
    arInfo.ZIndex = 4

    -- Toggle Auto Roll (ม่วงไล่เฉด + เงา)
    local arPill = Instance.new("TextButton", modeCard)
    arPill.Size = UDim2.new(0, 62, 0, 28)
    arPill.Position = UDim2.new(1, -76, 0, 78)
    arPill.BackgroundColor3 = Color3.fromRGB(10, 3, 20)
    arPill.Text = ""
    arPill.AutoButtonColor = false
    arPill.ZIndex = 4
    Instance.new("UICorner", arPill).CornerRadius = UDim.new(1, 0)

    local arGrad = Instance.new("UIGradient", arPill)
    arGrad.Rotation = 0
    arGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0.0, Theme.TogOffL),
        ColorSequenceKeypoint.new(1.0, Theme.TogOffR),
    }

    -- เงาขาว
    local arHi = Instance.new("Frame", arPill)
    arHi.Size = UDim2.new(0.6, 0, 0.6, 0)
    arHi.Position = UDim2.new(0, 0, 0, 0)
    arHi.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    arHi.BackgroundTransparency = 0.55
    arHi.BorderSizePixel = 0
    arHi.ZIndex = 1

    local arHiGrad = Instance.new("UIGradient", arHi)
    arHiGrad.Rotation = 135
    arHiGrad.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0.0, 0.35),
        NumberSequenceKeypoint.new(0.7, 1.0),
        NumberSequenceKeypoint.new(1.0, 1.0),
    }
    Instance.new("UICorner", arHi).CornerRadius = UDim.new(1, 0)

    local arK = Instance.new("Frame", arPill)
    arK.Size = UDim2.new(0, 22, 0, 22)
    arK.Position = UDim2.new(0, 3, 0.5, -11)
    arK.BackgroundColor3 = Color3.new(1,1,1)
    arK.BorderSizePixel = 0
    arK.ZIndex = 5
    Instance.new("UICorner", arK).CornerRadius = UDim.new(1, 0)

    arPill.MouseButton1Click:Connect(function()
        if State.running then stop() else start() end
        local on = State.running

        arGrad.Color = on and ColorSequence.new{
            ColorSequenceKeypoint.new(0.0, Theme.TogOnL),
            ColorSequenceKeypoint.new(1.0, Theme.TogOnR),
        } or ColorSequence.new{
            ColorSequenceKeypoint.new(0.0, Theme.TogOffL),
            ColorSequenceKeypoint.new(1.0, Theme.TogOffR),
        }
        TweenService:Create(arK, TweenInfo.new(0.25), {
            Position = on and UDim2.new(1, -25, 0.5, -11) or UDim2.new(0, 3, 0.5, -11),
        }):Play()
        arInfo.Text = on and "rolling..." or "click to start rolling"
        arInfo.TextColor3 = on and Theme.Good or Theme.AccentLt
    end)

    --=================================================================
    -- SPEED CARD
    --=================================================================
    local speedCard = makeCard(mainPage, UDim2.new(1, -36, 0, 62), UDim2.new(0, 18, 0, 192))

    local spdLbl = Instance.new("TextLabel", speedCard)
    spdLbl.Text = "SPAM SPEED"
    spdLbl.Font = Enum.Font.GothamBold
    spdLbl.TextSize = 9.5
    spdLbl.TextColor3 = Theme.AccentLt
    spdLbl.BackgroundTransparency = 1
    spdLbl.Size = UDim2.new(0.5, 0, 0, 14)
    spdLbl.Position = UDim2.new(0, 12, 0, 8)
    spdLbl.TextXAlignment = Enum.TextXAlignment.Left
    spdLbl.ZIndex = 4

    local spdVal = Instance.new("TextLabel", speedCard)
    spdVal.Text = "33 / sec"
    spdVal.Font = Enum.Font.GothamBold
    spdVal.TextSize = 11
    spdVal.TextColor3 = Theme.Text
    spdVal.BackgroundTransparency = 1
    spdVal.Size = UDim2.new(0.5, -12, 0, 14)
    spdVal.Position = UDim2.new(0.5, 0, 0, 8)
    spdVal.TextXAlignment = Enum.TextXAlignment.Right
    spdVal.ZIndex = 4

    local track = Instance.new("TextButton", speedCard)
    track.Size = UDim2.new(1, -24, 0, 10)
    track.Position = UDim2.new(0, 12, 0, 36)
    track.BackgroundColor3 = Color3.fromRGB(6, 2, 12)
    track.BorderSizePixel = 0
    track.Text = ""
    track.AutoButtonColor = false
    track.ZIndex = 4
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame", track)
    fill.Size = UDim2.new(0.5, 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 5
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local fillG = Instance.new("UIGradient", fill)
    fillG.Color = ColorSequence.new(Theme.Accent2, Theme.AccentLt)

    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0.5, -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 6
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

    --=================================================================
    -- COLLECT CARD
    --=================================================================
    local collectCard = makeCard(mainPage, UDim2.new(1, -36, 0, 62), UDim2.new(0, 18, 0, 262))

    makeToggle(collectCard, 8, "💰 AFK Collect Money",
        State.autoCollect,
        function(v)
            if v then startCollect() else stopCollect() end
        end, 46, 24, UDim2.new(1, -60, 0, 8))

    local acInfo = Instance.new("TextLabel", collectCard)
    acInfo.Text = string.format("every %.1fs · plot %d→%d",
        State.collectRate, State.plotMin, State.plotMax)
    acInfo.Font = Enum.Font.Gotham
    acInfo.TextSize = 9
    acInfo.TextColor3 = Theme.AccentLt
    acInfo.BackgroundTransparency = 1
    acInfo.Size = UDim2.new(1, -28, 0, 14)
    acInfo.Position = UDim2.new(0, 14, 0, 38)
    acInfo.TextXAlignment = Enum.TextXAlignment.Left
    acInfo.ZIndex = 4

    --=================================================================
    -- SETTINGS PAGE
    --=================================================================
    local settingsPage = Instance.new("Frame")
    settingsPage.Size = UDim2.new(1, 0, 1, 0)
    settingsPage.BackgroundTransparency = 1
    settingsPage.Visible = false
    settingsPage.Parent = content

    local sHeader = makeCard(settingsPage, UDim2.new(1, -36, 0, 46), UDim2.new(0, 18, 0, 16))

    local sTitle = Instance.new("TextLabel", sHeader)
    sTitle.Text = "⚙  Settings"
    sTitle.Font = Enum.Font.GothamBold
    sTitle.TextSize = 12
    sTitle.TextColor3 = Theme.Text
    sTitle.BackgroundTransparency = 1
    sTitle.Size = UDim2.new(1, -30, 1, 0)
    sTitle.Position = UDim2.new(0, 16, 0, 0)
    sTitle.TextXAlignment = Enum.TextXAlignment.Left
    sTitle.ZIndex = 4

    local setCard = makeCard(settingsPage, UDim2.new(1, -36, 0, 90), UDim2.new(0, 18, 0, 76))

    makeToggle(setCard, 12, "Bypass Roll Animation",
        State.bypassAnim,
        function(v) State.bypassAnim = v end)

    makeToggle(setCard, 48, "Kill Camera Cutscene",
        State.killCutscene,
        function(v) State.killCutscene = v end)

    local rangeCard = makeCard(settingsPage, UDim2.new(1, -36, 0, 76), UDim2.new(0, 18, 0, 178))

    local rcLbl = Instance.new("TextLabel", rangeCard)
    rcLbl.Text = "PLOT RANGE"
    rcLbl.Font = Enum.Font.GothamBold
    rcLbl.TextSize = 9.5
    rcLbl.TextColor3 = Theme.AccentLt
    rcLbl.BackgroundTransparency = 1
    rcLbl.Size = UDim2.new(1, -28, 0, 14)
    rcLbl.Position = UDim2.new(0, 14, 0, 8)
    rcLbl.TextXAlignment = Enum.TextXAlignment.Left
    rcLbl.ZIndex = 4

    local rcVal = Instance.new("TextLabel", rangeCard)
    rcVal.Text = string.format("1 → %d", State.plotMax)
    rcVal.Font = Enum.Font.Gotham
    rcVal.TextSize = 10
    rcVal.TextColor3 = Theme.Text
    rcVal.BackgroundTransparency = 1
    rcVal.Size = UDim2.new(1, -28, 0, 14)
    rcVal.Position = UDim2.new(0, 14, 0, 26)
    rcVal.TextXAlignment = Enum.TextXAlignment.Left
    rcVal.ZIndex = 4

    local function rangeBtn(txt, xPos, val)
        local b = Instance.new("TextButton", rangeCard)
        b.Size = UDim2.new(0, 52, 0, 26)
        b.Position = UDim2.new(0, xPos, 0, 44)
        b.BackgroundColor3 = Theme.Card1
        b.BackgroundTransparency = 0.15
        b.Text = txt
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.TextColor3 = Theme.Text
        b.AutoButtonColor = false
        b.ZIndex = 4
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)

        b.MouseButton1Click:Connect(function()
            State.plotMin, State.plotMax = 1, val
            rcVal.Text = string.format("1 → %d", State.plotMax)
            acInfo.Text = string.format("every %.1fs · plot %d→%d",
                State.collectRate, State.plotMin, State.plotMax)
        end)
        return b
    end

    rangeBtn("1 → 4", 14, 4)
    rangeBtn("1 → 8", 72, 8)
    rangeBtn("1 → 16", 130, 16)

    --=================================================================
    -- PAGE SWITCHER
    --=================================================================
    local function applyPage()
        for p, data in pairs(pageBtns) do
            local on = (p == State.page)
            data.glow.Visible = on
            data.name.TextColor3 = on and Theme.Text or Theme.TextDim
            data.icon.TextColor3 = on and Theme.Text or Theme.AccentLt
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

    --=================================================================
    -- ปุ่มมุมขวาบน
    --=================================================================
    local topBtnsFrame = Instance.new("Frame")
    topBtnsFrame.Size = UDim2.new(0, 60, 0, 22)
    topBtnsFrame.Position = UDim2.new(1, -70, 0, 10)
    topBtnsFrame.BackgroundTransparency = 1
    topBtnsFrame.ZIndex = 10
    topBtnsFrame.Parent = win

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 22, 0, 22)
    minBtn.Position = UDim2.new(0, 0, 0, 0)
    minBtn.BackgroundColor3 = Theme.Card1
    minBtn.BackgroundTransparency = 0.3
    minBtn.BorderSizePixel = 0
    minBtn.Text = "—"
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 14
    minBtn.TextColor3 = Theme.Text
    minBtn.AutoButtonColor = false
    minBtn.ZIndex = 11
    minBtn.Parent = topBtnsFrame
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(1, 0)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(0, 32, 0, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 20, 35)
    closeBtn.BackgroundTransparency = 0.15
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.TextColor3 = Theme.Text
    closeBtn.AutoButtonColor = false
    closeBtn.ZIndex = 11
    closeBtn.Parent = topBtnsFrame
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)

    minBtn.MouseEnter:Connect(function()
        TweenService:Create(minBtn, TweenInfo.new(0.15), {BackgroundTransparency=0.1}):Play()
    end)
    minBtn.MouseLeave:Connect(function()
        TweenService:Create(minBtn, TweenInfo.new(0.15), {BackgroundTransparency=0.3}):Play()
    end)
    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundTransparency=0.0}):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundTransparency=0.15}):Play()
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
        if blur then blur.Size = 10 end
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

print("[AxionHub] v11 ready.")
