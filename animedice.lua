--[[
    AxionHub :: AutoDice  [LOCKED v1]
    Anime Dice auto-roll — args confirmed from runtime spy
      RollDice:InvokeServer()          -- no args
      SetAutoRoll:FireServer(true)     -- bool
    UI: purple-black gradient
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer
local RS = ReplicatedStorage

--=====================================================================
-- REMOTES (confirmed from spy)
--=====================================================================
local RollDice    = RS:WaitForChild("Network", 10)
                    and RS.Network:WaitForChild("RollService", 10)
                    and RS.Network.RollService:WaitForChild("RF", 10)
                    and RS.Network.RollService.RF:WaitForChild("RollDice", 10)

local SetAutoRoll = RS:WaitForChild("Network", 10)
                    and RS.Network:WaitForChild("RollService", 10)
                    and RS.Network.RollService:WaitForChild("RE", 10)
                    and RS.Network.RollService.RE:WaitForChild("SetAutoRoll", 10)

local RollMessage = RS:WaitForChild("Network", 10)
                    and RS.Network:WaitForChild("RollService", 10)
                    and RS.Network.RollService:WaitForChild("RE", 10)
                    and RS.Network.RollService.RE:WaitForChild("RollMessage", 10)

if not RollDice or not SetAutoRoll then
    warn("[AxionHub] RollService not found. Not on Anime Dice?")
    return
end

--=====================================================================
-- THEME
--=====================================================================
local Theme = {
    BgTop=Color3.fromRGB(28,12,48), BgMid=Color3.fromRGB(20,8,38), BgBottom=Color3.fromRGB(10,6,18),
    Accent=Color3.fromRGB(155,60,235), Accent2=Color3.fromRGB(90,20,150),
    Text=Color3.fromRGB(235,225,255), SubText=Color3.fromRGB(170,150,200),
    Border=Color3.fromRGB(120,40,200), Button=Color3.fromRGB(60,20,110),
    ButtonHov=Color3.fromRGB(110,40,190), Good=Color3.fromRGB(150,255,180),
    Bad=Color3.fromRGB(255,90,90),
}

--=====================================================================
-- STATE
--=====================================================================
local State = {
    mode        = "AUTO",     -- "SPAM" | "AUTO" | "BOTH"
    running     = false,
    rolls       = 0,
    autoRollOn  = false,
    thread      = nil,
    spamSpeed   = 0.05,       -- 20 rolls/sec (SPAM/BOTH)
    lastRoll    = 0,
    results     = {},         -- captures RollMessage payloads
}

--=====================================================================
-- ANIMATION SUPPRESSION
--=====================================================================
local function suppressAnimation()
    -- Kill roll cutscene camera model
    local rolling = RS:FindFirstChild("Framework")
                    and RS.Framework.Features
                    and RS.Framework.Features:FindFirstChild("Rolling")
    if rolling then
        local rc = rolling:FindFirstChild("RollCutscene")
        if rc then
            local cam = rc:FindFirstChild("CameraModel")
            if cam then pcall(function() cam:Destroy() end) end
        end
    end

    -- Kill impact frames on Lighting
    local Lighting = game:GetService("Lighting")
    for _, name in ipairs({"VFXImpactFrameWhite","WhiteImpactFrame","BlackImpactFrame","VFXImpactFrameBlack"}) do
        local fx = Lighting:FindFirstChild(name)
        if fx and fx:IsA("ColorCorrectionEffect") then
            fx.Enabled = false
        end
    end

    -- Hide Rolling folder in PlayerGui Root
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if pg then
        local root = pg:FindFirstChild("Root")
        if root and root:FindFirstChild("Rolling") then
            root.Rolling.Visible = false
        end
    end
end

suppressAnimation()

--=====================================================================
-- ROLL (confirmed: no args)
--=====================================================================
local function doRoll()
    local ok = pcall(function()
        RollDice:InvokeServer()
    end)
    if ok then
        State.rolls = State.rolls + 1
    end

    if (State.mode == "AUTO" or State.mode == "BOTH") and not State.autoRollOn then
        pcall(function()
            SetAutoRoll:FireServer(true)
            State.autoRollOn = true
        end)
    end

    return ok
end

--=====================================================================
-- MAIN LOOP
--=====================================================================
local function loop()
    State.running = true
    while State.running do
        if State.mode == "SPAM" or State.mode == "BOTH" then
            doRoll()
        elseif State.mode == "AUTO" then
            if not State.autoRollOn then
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
    State.thread = task.spawn(loop)
end

local function stop()
    State.running = false
    if State.thread then pcall(task.cancel, State.thread) end
    if State.autoRollOn then
        pcall(function() SetAutoRoll:FireServer(false) end)
        State.autoRollOn = false
    end
end

--=====================================================================
-- CAPTURE RESULTS (optional, for logging what you rolled)
--=====================================================================
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
    local existing = game:GetService("CoreGui"):FindFirstChild("AxionHub_AutoDice")
    if existing then existing:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "AxionHub_AutoDice"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = game:GetService("CoreGui")

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 380, 0, 360)
    main.Position = UDim2.new(0.5, -190, 0.5, -180)
    main.BackgroundColor3 = Theme.BgBottom
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = gui

    local grad = Instance.new("UIGradient")
    grad.Rotation = 90
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Theme.BgTop),
        ColorSequenceKeypoint.new(0.5, Theme.BgMid),
        ColorSequenceKeypoint.new(1, Theme.BgBottom),
    }
    grad.Parent = main

    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Border
    stroke.Thickness = 2
    stroke.Transparency = 0.2
    stroke.Parent = main

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = main

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 44)
    header.BackgroundColor3 = Theme.Accent2
    header.BorderSizePixel = 0
    header.Parent = main

    local hGrad = Instance.new("UIGradient")
    hGrad.Color = ColorSequence.new(Theme.Accent, Theme.Accent2)
    hGrad.Parent = header

    local hCorner = Instance.new("UICorner")
    hCorner.CornerRadius = UDim.new(0, 10)
    hCorner.Parent = header

    local hFix = Instance.new("Frame")
    hFix.Size = UDim2.new(1, 0, 0, 12)
    hFix.Position = UDim2.new(0, 0, 1, -12)
    hFix.BackgroundColor3 = Theme.Accent2
    hFix.BorderSizePixel = 0
    hFix.Parent = header

    local title = Instance.new("TextLabel")
    title.Text = "AxionHub  •  AutoDice"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 17
    title.TextColor3 = Theme.Text
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -50, 1, 0)
    title.Position = UDim2.new(0, 14, 0, 0)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local close = Instance.new("TextButton")
    close.Text = "✕"
    close.Font = Enum.Font.GothamBold
    close.TextSize = 15
    close.TextColor3 = Theme.Text
    close.BackgroundTransparency = 1
    close.Size = UDim2.new(0, 34, 0, 34)
    close.Position = UDim2.new(1, -40, 0, 5)
    close.Parent = header
    close.MouseButton1Click:Connect(function() stop(); gui:Destroy() end)

    -- Status
    local status = Instance.new("TextLabel")
    status.Font = Enum.Font.Gotham
    status.TextSize = 11
    status.TextColor3 = Theme.SubText
    status.BackgroundTransparency = 1
    status.Size = UDim2.new(1, -40, 0, 16)
    status.Position = UDim2.new(0, 20, 0, 58)
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = main

    task.spawn(function()
        while status.Parent do
            status.Text = string.format("mode: %s   |   rolls: %d   |   autoroll: %s",
                State.mode, State.rolls, State.autoRollOn and "ON" or "off")
            task.wait(0.3)
        end
    end)

    -- Mode buttons
    local modes = {"AUTO", "SPAM", "BOTH"}
    local yStart, rowH = 88, 40

    local modeButtons = {}
    for i, m in ipairs(modes) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -40, 0, 34)
        btn.Position = UDim2.new(0, 20, 0, yStart + (i - 1) * rowH)
        btn.BackgroundColor3 = (State.mode == m) and Theme.ButtonHov or Theme.Button
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Text = ""
        btn.Parent = main

        local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 6); bc.Parent = btn
        local bs = Instance.new("UIStroke"); bs.Color = Theme.Border; bs.Thickness = 1; bs.Transparency = 0.5; bs.Parent = btn

        local marker = Instance.new("Frame")
        marker.Size = UDim2.new(0, 4, 0, 22)
        marker.Position = UDim2.new(0, 0, 0.5, -11)
        marker.BackgroundColor3 = Theme.Accent
        marker.BorderSizePixel = 0
        marker.Parent = btn
        local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0, 2); mc.Parent = marker

        local labels = {
            AUTO = "AUTO  —  set & forget (recommended)",
            SPAM = "SPAM  —  invoke 20x/sec",
            BOTH = "BOTH  —  autoroll + spam",
        }

        local txt = Instance.new("TextLabel")
        txt.Text = labels[m]
        txt.Font = Enum.Font.GothamMedium
        txt.TextSize = 12
        txt.TextColor3 = Theme.Text
        txt.BackgroundTransparency = 1
        txt.Size = UDim2.new(1, -20, 1, 0)
        txt.Position = UDim2.new(0, 16, 0, 0)
        txt.TextXAlignment = Enum.TextXAlignment.Left
        txt.Parent = btn

        modeButtons[m] = btn

        btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Theme.ButtonHov end)
        btn.MouseLeave:Connect(function()
            btn.BackgroundColor3 = (State.mode == m) and Theme.ButtonHov or Theme.Button
        end)

        btn.MouseButton1Click:Connect(function()
            State.mode = m
            for mm, bb in pairs(modeButtons) do
                bb.BackgroundColor3 = (mm == State.mode) and Theme.ButtonHov or Theme.Button
            end
        end)
    end

    -- Speed slider (SPAM only)
    local speedLabel = Instance.new("TextLabel")
    speedLabel.Text = "SPAM SPEED"
    speedLabel.Font = Enum.Font.GothamBold
    speedLabel.TextSize = 11
    speedLabel.TextColor3 = Theme.SubText
    speedLabel.BackgroundTransparency = 1
    speedLabel.Size = UDim2.new(1, -40, 0, 16)
    speedLabel.Position = UDim2.new(0, 20, 0, yStart + 3 * rowH + 6)
    speedLabel.TextXAlignment = Enum.TextXAlignment.Left
    speedLabel.Parent = main

    local speedVal = Instance.new("TextLabel")
    speedVal.Text = "20 / sec"
    speedVal.Font = Enum.Font.Gotham
    speedVal.TextSize = 11
    speedVal.TextColor3 = Theme.Accent
    speedVal.BackgroundTransparency = 1
    speedVal.Size = UDim2.new(0, 100, 0, 16)
    speedVal.Position = UDim2.new(1, -120, 0, yStart + 3 * rowH + 6)
    speedVal.TextXAlignment = Enum.TextXAlignment.Right
    speedVal.Parent = main

    local track = Instance.new("TextButton")
    track.Size = UDim2.new(1, -40, 0, 8)
    track.Position = UDim2.new(0, 20, 0, yStart + 3 * rowH + 28)
    track.BackgroundColor3 = Theme.Button
    track.BorderSizePixel = 0
    track.Text = ""
    track.AutoButtonColor = false
    track.Parent = main
    local tCorner = Instance.new("UICorner"); tCorner.CornerRadius = UDim.new(1, 0); tCorner.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0.5, 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    local fCorner = Instance.new("UICorner"); fCorner.CornerRadius = UDim.new(1, 0); fCorner.Parent = fill

    local dragging = false
    local function setFromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        -- map 0..1 -> 50/sec .. 200/sec
        local rate = math.floor(50 + rel * 150)
        State.spamSpeed = 1 / rate
        speedVal.Text = rate .. " / sec"
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(input.Position.X)
        end
    end)
    track.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end)
    track.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- Start / Stop
    local startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.new(0.5, -26, 0, 40)
    startBtn.Position = UDim2.new(0, 20, 1, -60)
    startBtn.BackgroundColor3 = Theme.Button
    startBtn.BorderSizePixel = 0
    startBtn.Text = "START"
    startBtn.Font = Enum.Font.GothamBold
    startBtn.TextSize = 14
    startBtn.TextColor3 = Theme.Text
    startBtn.AutoButtonColor = false
    startBtn.Parent = main
    local sbc = Instance.new("UICorner"); sbc.CornerRadius = UDim.new(0, 6); sbc.Parent = startBtn
    local sbs = Instance.new("UIStroke"); sbs.Color = Theme.Border; sbs.Thickness = 1; sbs.Transparency = 0.4; sbs.Parent = startBtn

    local stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.new(0.5, -26, 0, 40)
    stopBtn.Position = UDim2.new(0.5, 6, 1, -60)
    stopBtn.BackgroundColor3 = Theme.Button
    stopBtn.BorderSizePixel = 0
    stopBtn.Text = "STOP"
    stopBtn.Font = Enum.Font.GothamBold
    stopBtn.TextSize = 14
    stopBtn.TextColor3 = Theme.Text
    stopBtn.AutoButtonColor = false
    stopBtn.Parent = main
    local tbc = Instance.new("UICorner"); tbc.CornerRadius = UDim.new(0, 6); tbc.Parent = stopBtn
    local tbs = Instance.new("UIStroke"); tbs.Color = Theme.Border; tbs.Thickness = 1; tbs.Transparency = 0.4; tbs.Parent = stopBtn

    startBtn.MouseButton1Click:Connect(function()
        start()
        startBtn.Text = "RUNNING"
        startBtn.TextColor3 = Theme.Good
    end)
    stopBtn.MouseButton1Click:Connect(function()
        stop()
        startBtn.Text = "START"
        startBtn.TextColor3 = Theme.Text
    end)

    startBtn.MouseEnter:Connect(function() startBtn.BackgroundColor3 = Theme.ButtonHov end)
    startBtn.MouseLeave:Connect(function() startBtn.BackgroundColor3 = Theme.Button end)
    stopBtn.MouseEnter:Connect(function() stopBtn.BackgroundColor3 = Theme.ButtonHov end)
    stopBtn.MouseLeave:Connect(function() stopBtn.BackgroundColor3 = Theme.Button end)

    -- Footer
    local footer = Instance.new("TextLabel")
    footer.Text = "args confirmed: RollDice()  •  SetAutoRoll(bool)"
    footer.Font = Enum.Font.Gotham
    footer.TextSize = 10
    footer.TextColor3 = Theme.SubText
    footer.BackgroundTransparency = 1
    footer.Size = UDim2.new(1, -40, 0, 14)
    footer.Position = UDim2.new(0, 20, 1, -18)
    footer.TextXAlignment = Enum.TextXAlignment.Left
    footer.Parent = main
end

buildUI()
print("[AxionHub] AutoDice v1 loaded. Pick mode, hit START.")