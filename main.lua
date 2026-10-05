-- ============================================================
-- EXECUTE HUB - v9.2.0
-- With Getkey Verification Gate
-- ============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")
local VirtualUser      = game:GetService("VirtualUser")
local Workspace        = game:GetService("Workspace")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")
local RbxAnalytics     = game:GetService("RbxAnalyticsService")
local LocalPlayer      = Players.LocalPlayer

local GETKEY_API       = "https://getkeyxcl.vercel.app"
local VERIFY_ENDPOINT  = GETKEY_API .. "/api/key/verify"
local STORAGE_KEY      = "executehub_key_v1"

local Config = {
    BgMain      = Color3.fromRGB(15, 15, 18),
    BgSidebar   = Color3.fromRGB(10, 10, 12),
    BgContent   = Color3.fromRGB(8, 8, 10),
    BgCard      = Color3.fromRGB(28, 28, 34),
    BgHover     = Color3.fromRGB(45, 45, 55),
    Accent      = Color3.fromRGB(255, 35, 45),
    AccentHover = Color3.fromRGB(255, 60, 70),
    TextPrimary = Color3.fromRGB(245, 245, 250),
    TextSecond  = Color3.fromRGB(160, 160, 175),
    TextMuted   = Color3.fromRGB(110, 110, 125),
    Border      = Color3.fromRGB(255, 255, 255),
    BorderTransp= 0.9,
    Success     = Color3.fromRGB(60, 220, 110),
    Version     = "v9.2.0"
}

local State = {
    BypassEnabled=false, BypassRange=500, RemoveCollision=false, AutoEnterLocked=false,
    SpeedEnabled=false, SpeedValue=16, MaxSpeed=250,
    FlyEnabled=false, FlySpeed=60,
    NoclipEnabled=false, InfJumpEnabled=false, AntiFlingEnabled=false, AntiVoidEnabled=false,
    AntiBanEnabled=true, JitterEnabled=true, RateLimitEnabled=true, LegitMode=false, RampUpEnabled=true,
    ShowCoords=true, AntiAfkEnabled=true, AutoUpdateCheck=true, SavedPositions={},
}

local AntiBan = { tickCounter = 0, currentRampSpeed = 16 }

-- ============================================================
-- CLEANUP
-- ============================================================
for _, name in ipairs({"ExecuteHub", "ExecuteHubLoading", "ExecuteHubVerify", "ExecuteHubHUD"}) do
    pcall(function()
        local o = CoreGui:FindFirstChild(name)
        if o then o:Destroy() end
    end)
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg and pg:FindFirstChild(name) then pg[name]:Destroy() end
    end)
end

-- ============================================================
-- HWID
-- ============================================================
local function getHWID()
    local ok, id = pcall(function()
        return RbxAnalytics:GetClientId()
    end)
    if ok and id then return id end
    return "fallback-" .. tostring(LocalPlayer.UserId)
end

local HWID = getHWID()

-- ============================================================
-- VERIFY API
-- ============================================================
local function verifyKey(key)
    local payload = HttpService:JSONEncode({ key = key, hwid = HWID })

    local ok, response = pcall(function()
        return HttpService:RequestAsync({
            Url = VERIFY_ENDPOINT,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = payload
        })
    end)

    if not ok then return false, "network_error" end
    if not response.Success then return false, "server_error" end

    local decoded
    local decodeOk = pcall(function()
        decoded = HttpService:JSONDecode(response.Body)
    end)
    if not decodeOk or type(decoded) ~= "table" then
        return false, "invalid_response"
    end

    if decoded.valid == true then
        return true, nil
    end
    return false, decoded.reason or "invalid"
end

-- ============================================================
-- LOADING SCREEN
-- ============================================================
local LoadingGui = Instance.new("ScreenGui")
LoadingGui.Name = "ExecuteHubLoading"
LoadingGui.ResetOnSpawn = false
LoadingGui.IgnoreGuiInset = true
LoadingGui.DisplayOrder = 1000
pcall(function() LoadingGui.Parent = CoreGui end)
if not LoadingGui.Parent then LoadingGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local LF = Instance.new("Frame")
LF.Size = UDim2.new(0, 340, 0, 180)
LF.Position = UDim2.new(0.5, -170, 0.5, -90)
LF.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
LF.BorderSizePixel = 0
LF.Parent = LoadingGui
local LFC = Instance.new("UICorner") LFC.CornerRadius = UDim.new(0, 14) LFC.Parent = LF
local LFS = Instance.new("UIStroke") LFS.Color = Config.Accent LFS.Thickness = 1.5 LFS.Parent = LF

local LL = Instance.new("TextLabel")
LL.Size = UDim2.new(1, 0, 0, 40); LL.Position = UDim2.new(0, 0, 0, 20)
LL.BackgroundTransparency = 1; LL.Text = "EXECUTE HUB"
LL.TextColor3 = Config.Accent; LL.TextSize = 24; LL.Font = Enum.Font.GothamBlack; LL.Parent = LF

local LV = Instance.new("TextLabel")
LV.Size = UDim2.new(1, 0, 0, 14); LV.Position = UDim2.new(0, 0, 0, 58)
LV.BackgroundTransparency = 1; LV.Text = Config.Version
LV.TextColor3 = Color3.fromRGB(110, 110, 125); LV.TextSize = 10; LV.Font = Enum.Font.Gotham; LV.Parent = LF

local LBB = Instance.new("Frame")
LBB.Size = UDim2.new(0, 260, 0, 6); LBB.Position = UDim2.new(0.5, -130, 0, 100)
LBB.BackgroundColor3 = Color3.fromRGB(45, 45, 55); LBB.BorderSizePixel = 0; LBB.Parent = LF
local LBBC = Instance.new("UICorner") LBBC.CornerRadius = UDim.new(1, 0) LBBC.Parent = LBB

local LBF = Instance.new("Frame")
LBF.Size = UDim2.new(0, 0, 1, 0); LBF.BackgroundColor3 = Config.Accent
LBF.BorderSizePixel = 0; LBF.Parent = LBB
local LBFC = Instance.new("UICorner") LBFC.CornerRadius = UDim.new(1, 0) LBFC.Parent = LBF

local LS = Instance.new("TextLabel")
LS.Size = UDim2.new(1, 0, 0, 14); LS.Position = UDim2.new(0, 0, 0, 120)
LS.BackgroundTransparency = 1; LS.Text = "Loading..."
LS.TextColor3 = Color3.fromRGB(160, 160, 175); LS.TextSize = 10; LS.Font = Enum.Font.GothamBold; LS.Parent = LF

task.spawn(function()
    local steps = {"Loading modules...", "Checking updates...", "Setting up UI...", "Ready!"}
    for i = 1, 4 do
        LS.Text = steps[i]
        TweenService:Create(LBF, TweenInfo.new(0.3), { Size = UDim2.new(i/4, 0, 1, 0) }):Play()
        task.wait(0.3)
    end
    task.wait(0.2)
    for _, obj in ipairs(LF:GetDescendants()) do
        if obj:IsA("TextLabel") then
            TweenService:Create(obj, TweenInfo.new(0.35), {TextTransparency=1}):Play()
        elseif obj:IsA("Frame") then
            TweenService:Create(obj, TweenInfo.new(0.35), {BackgroundTransparency=1}):Play()
        elseif obj:IsA("UIStroke") then
            TweenService:Create(obj, TweenInfo.new(0.35), {Transparency=1}):Play()
        end
    end
    task.wait(0.45)
    LoadingGui:Destroy()
end)

task.wait(2.0)

-- ============================================================
-- VERIFY SCREEN
-- ============================================================
local Verified = false

local function buildVerifyScreen(onSuccess)
    local VGui = Instance.new("ScreenGui")
    VGui.Name = "ExecuteHubVerify"
    VGui.ResetOnSpawn = false
    VGui.IgnoreGuiInset = true
    VGui.DisplayOrder = 998
    pcall(function() VGui.Parent = CoreGui end)
    if not VGui.Parent then VGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local Bg = Instance.new("Frame")
    Bg.Size = UDim2.new(1, 0, 1, 0)
    Bg.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    Bg.BackgroundTransparency = 0.15
    Bg.BorderSizePixel = 0
    Bg.Parent = VGui

    local Card = Instance.new("Frame")
    Card.Size = UDim2.new(0, 380, 0, 260)
    Card.Position = UDim2.new(0.5, -190, 0.5, -130)
    Card.BackgroundColor3 = Config.BgMain
    Card.BackgroundTransparency = 0.05
    Card.BorderSizePixel = 0
    Card.Active = true
    Card.Draggable = true
    Card.Parent = VGui
    local CardC = Instance.new("UICorner") CardC.CornerRadius = UDim.new(0, 14) CardC.Parent = Card
    local CardS = Instance.new("UIStroke") CardS.Color = Config.Accent CardS.Thickness = 1.5 CardS.Transparency = 0.3 CardS.Parent = Card

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -32, 0, 32)
    Title.Position = UDim2.new(0, 16, 0, 20)
    Title.BackgroundTransparency = 1
    Title.Text = "EXECUTE HUB"
    Title.TextColor3 = Config.Accent
    Title.TextSize = 22
    Title.Font = Enum.Font.GothamBlack
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Card

    local Badge = Instance.new("TextLabel")
    Badge.Size = UDim2.new(0, 60, 0, 20)
    Badge.Position = UDim2.new(1, -76, 0, 26)
    Badge.BackgroundColor3 = Color3.fromRGB(46, 26, 26)
    Badge.Text = "KEY"
    Badge.TextColor3 = Config.Accent
    Badge.TextSize = 10
    Badge.Font = Enum.Font.GothamBold
    Badge.Parent = Card
    local BadgeC = Instance.new("UICorner") BadgeC.CornerRadius = UDim.new(1, 0) BadgeC.Parent = Badge

    local Sub = Instance.new("TextLabel")
    Sub.Size = UDim2.new(1, -32, 0, 16)
    Sub.Position = UDim2.new(0, 16, 0, 56)
    Sub.BackgroundTransparency = 1
    Sub.Text = "Enter your key to continue"
    Sub.TextColor3 = Config.TextSecond
    Sub.TextSize = 12
    Sub.Font = Enum.Font.Gotham
    Sub.TextXAlignment = Enum.TextXAlignment.Left
    Sub.Parent = Card

    local InputFrame = Instance.new("Frame")
    InputFrame.Size = UDim2.new(1, -32, 0, 42)
    InputFrame.Position = UDim2.new(0, 16, 0, 92)
    InputFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    InputFrame.BorderSizePixel = 0
    InputFrame.Parent = Card
    local IFC = Instance.new("UICorner") IFC.CornerRadius = UDim.new(0, 8) IFC.Parent = InputFrame
    local IFS = Instance.new("UIStroke") IFS.Color = Color3.fromRGB(60, 60, 72) IFS.Thickness = 1 IFS.Parent = InputFrame

    local Input = Instance.new("TextBox")
    Input.Size = UDim2.new(1, -24, 1, 0)
    Input.Position = UDim2.new(0, 12, 0, 0)
    Input.BackgroundTransparency = 1
    Input.Text = ""
    Input.PlaceholderText = "XH-1DAY-XXXX-XXXX-XXXX"
    Input.TextColor3 = Config.TextPrimary
    Input.PlaceholderColor3 = Config.TextMuted
    Input.TextSize = 13
    Input.Font = Enum.Font.Code
    Input.TextXAlignment = Enum.TextXAlignment.Left
    Input.ClearTextOnFocus = false
    Input.Parent = InputFrame

    local HWIDLabel = Instance.new("TextLabel")
    HWIDLabel.Size = UDim2.new(1, -32, 0, 14)
    HWIDLabel.Position = UDim2.new(0, 16, 0, 140)
    HWIDLabel.BackgroundTransparency = 1
    HWIDLabel.Text = "HWID: " .. string.sub(HWID, 1, 24) .. "..."
    HWIDLabel.TextColor3 = Config.TextMuted
    HWIDLabel.TextSize = 9
    HWIDLabel.Font = Enum.Font.Code
    HWIDLabel.TextXAlignment = Enum.TextXAlignment.Left
    HWIDLabel.Parent = Card

    local VerifyBtn = Instance.new("TextButton")
    VerifyBtn.Size = UDim2.new(1, -32, 0, 42)
    VerifyBtn.Position = UDim2.new(0, 16, 0, 162)
    VerifyBtn.BackgroundColor3 = Config.Accent
    VerifyBtn.Text = "Verify Key"
    VerifyBtn.TextColor3 = Config.TextPrimary
    VerifyBtn.TextSize = 14
    VerifyBtn.Font = Enum.Font.GothamBold
    VerifyBtn.BorderSizePixel = 0
    VerifyBtn.AutoButtonColor = false
    VerifyBtn.Parent = Card
    local VBC = Instance.new("UICorner") VBC.CornerRadius = UDim.new(0, 8) VBC.Parent = VerifyBtn

    VerifyBtn.MouseEnter:Connect(function()
        TweenService:Create(VerifyBtn, TweenInfo.new(0.15), { BackgroundColor3 = Config.AccentHover }):Play()
    end)
    VerifyBtn.MouseLeave:Connect(function()
        TweenService:Create(VerifyBtn, TweenInfo.new(0.15), { BackgroundColor3 = Config.Accent }):Play()
    end)

    local Status = Instance.new("TextLabel")
    Status.Size = UDim2.new(1, -32, 0, 20)
    Status.Position = UDim2.new(0, 16, 0, 214)
    Status.BackgroundTransparency = 1
    Status.Text = ""
    Status.TextColor3 = Config.TextSecond
    Status.TextSize = 11
    Status.Font = Enum.Font.Gotham
    Status.TextXAlignment = Enum.TextXAlignment.Left
    Status.Parent = Card

    local verifying = false

    local function setStatus(text, color)
        Status.Text = text
        Status.TextColor3 = color or Config.TextSecond
    end

    local function attemptVerify()
        if verifying then return end
        local key = Input.Text
        if key == "" or #key < 8 then
            setStatus("Please enter a valid key", Color3.fromRGB(248, 113, 113))
            return
        end

        verifying = true
        VerifyBtn.Text = "Verifying..."
        VerifyBtn.BackgroundColor3 = Color3.fromRGB(82, 82, 91)
        setStatus("Contacting server...", Config.TextSecond)

        local valid, reason = verifyKey(key)

        verifying = false
        VerifyBtn.Text = "Verify Key"
        VerifyBtn.BackgroundColor3 = Config.Accent

        if valid then
            setStatus("Key accepted. Welcome.", Config.Success)
            Verified = true
            Input.Text = ""

            TweenService:Create(Card, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(CardS, TweenInfo.new(0.4), { Transparency = 1 }):Play()
            for _, obj in ipairs(Card:GetDescendants()) do
                if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    TweenService:Create(obj, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
                elseif obj:IsA("Frame") then
                    TweenService:Create(obj, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
                elseif obj:IsA("UIStroke") then
                    TweenService:Create(obj, TweenInfo.new(0.4), { Transparency = 1 }):Play()
                end
            end
            TweenService:Create(Bg, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()

            task.wait(0.45)
            VGui:Destroy()

            pcall(function()
                if writefile and isfolder then
                    writefile(STORAGE_KEY .. ".txt", key)
                end
            end)

            onSuccess()
        else
            local msg = "Invalid key"
            if reason == "expired" then
                msg = "Key expired"
            elseif reason == "hwid_mismatch" then
                msg = "Key bound to another device"
            elseif reason == "revoked" then
                msg = "Key revoked"
            elseif reason == "not_found" then
                msg = "Key not found"
            elseif reason == "rate_limited" then
                msg = "Too many attempts, wait a minute"
            elseif reason == "network_error" then
                msg = "Network error"
            elseif reason == "server_error" then
                msg = "Server error"
            elseif reason == "invalid_format" then
                msg = "Invalid key format"
            elseif reason == "invalid_hwid" then
                msg = "Invalid hardware id"
            end
            setStatus(msg, Color3.fromRGB(248, 113, 113))
            TweenService:Create(IFS, TweenInfo.new(0.15), { Color = Color3.fromRGB(248, 113, 113) }):Play()
            task.wait(0.6)
            TweenService:Create(IFS, TweenInfo.new(0.15), { Color = Color3.fromRGB(60, 60, 72) }):Play()
        end
    end

    VerifyBtn.MouseButton1Click:Connect(attemptVerify)
    Input.FocusLost:Connect(function(enter)
        if enter then
            attemptVerify()
        end
    end)
end

-- ============================================================
-- MAIN UI (Execute Hub)
-- ============================================================
local function buildMainUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ExecuteHub"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.DisplayOrder = 999
    pcall(function() ScreenGui.Parent = CoreGui end)
    if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 600, 0, 400)
    Main.Position = UDim2.new(0.5, -300, 0.5, -200)
    Main.BackgroundColor3 = Config.BgMain
    Main.BackgroundTransparency = 0.05
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = ScreenGui
    local MC = Instance.new("UICorner") MC.CornerRadius = UDim.new(0, 14) MC.Parent = Main
    local MS = Instance.new("UIStroke") MS.Color = Config.Border MS.Thickness = 1 MS.Transparency = Config.BorderTransp MS.Parent = Main

    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 40)
    TopBar.BackgroundColor3 = Config.BgSidebar
    TopBar.BackgroundTransparency = 0.1
    TopBar.BorderSizePixel = 0
    TopBar.Parent = Main
    local TBC = Instance.new("UICorner") TBC.CornerRadius = UDim.new(0, 14) TBC.Parent = TopBar
    local TBCover = Instance.new("Frame")
    TBCover.Size = UDim2.new(1, 0, 0, 15); TBCover.Position = UDim2.new(0, 0, 1, -15)
    TBCover.BackgroundColor3 = Config.BgSidebar; TBCover.BackgroundTransparency = 0.1; TBCover.BorderSizePixel = 0; TBCover.Parent = TopBar

    local dots = Instance.new("Frame")
    dots.Size = UDim2.new(0, 50, 0, 12); dots.Position = UDim2.new(0, 12, 0.5, -6)
    dots.BackgroundTransparency = 1; dots.Parent = TopBar
    local dotColors = {Color3.fromRGB(255,95,87), Color3.fromRGB(255,189,46), Color3.fromRGB(39,201,63)}
    for i = 1, 3 do
        local d = Instance.new("Frame")
        d.Size = UDim2.new(0, 9, 0, 9); d.Position = UDim2.new(0, (i-1)*12, 0.5, -4.5)
        d.BackgroundColor3 = dotColors[i]; d.BorderSizePixel = 0; d.Parent = dots
        local dc = Instance.new("UICorner") dc.CornerRadius = UDim.new(1, 0) dc.Parent = d
    end

    local TTitle = Instance.new("TextLabel")
    TTitle.Size = UDim2.new(0, 300, 0, 18); TTitle.Position = UDim2.new(0, 66, 0, 6)
    TTitle.BackgroundTransparency = 1; TTitle.Text = "EXECUTE HUB"
    TTitle.TextColor3 = Config.TextPrimary; TTitle.TextSize = 13; TTitle.Font = Enum.Font.GothamBold
    TTitle.TextXAlignment = Enum.TextXAlignment.Left; TTitle.Parent = TopBar

    local TSub = Instance.new("TextLabel")
    TSub.Size = UDim2.new(0, 300, 0, 12); TSub.Position = UDim2.new(0, 66, 0, 22)
    TSub.BackgroundTransparency = 1; TSub.Text = "Verified • " .. Config.Version
    TSub.TextColor3 = Config.Success; TSub.TextSize = 9; TSub.Font = Enum.Font.Gotham
    TSub.TextXAlignment = Enum.TextXAlignment.Left; TSub.Parent = TopBar

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 22, 0, 22); CloseBtn.Position = UDim2.new(1, -30, 0.5, -11)
    CloseBtn.BackgroundColor3 = Config.Accent; CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Config.TextPrimary; CloseBtn.TextSize = 11; CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.BorderSizePixel = 0; CloseBtn.AutoButtonColor = false; CloseBtn.Parent = TopBar
    local CC = Instance.new("UICorner") CC.CornerRadius = UDim.new(0, 6) CC.Parent = CloseBtn

    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 22, 0, 22); MinBtn.Position = UDim2.new(1, -54, 0.5, -11)
    MinBtn.BackgroundColor3 = Config.BgCard; MinBtn.BackgroundTransparency = 0.5
    MinBtn.Text = "−"; MinBtn.TextColor3 = Config.TextPrimary; MinBtn.TextSize = 14
    MinBtn.Font = Enum.Font.GothamBold; MinBtn.BorderSizePixel = 0
    MinBtn.AutoButtonColor = false; MinBtn.Parent = TopBar
    local MinC = Instance.new("UICorner") MinC.CornerRadius = UDim.new(0, 6) MinC.Parent = MinBtn

    local Sidebar = Instance.new("Frame")
    Sidebar.Size = UDim2.new(0, 150, 1, -48); Sidebar.Position = UDim2.new(0, 0, 0, 40)
    Sidebar.BackgroundColor3 = Config.BgSidebar
    Sidebar.BackgroundTransparency = 0.15
    Sidebar.BorderSizePixel = 0; Sidebar.Parent = Main
    local SBC = Instance.new("UICorner") SBC.CornerRadius = UDim.new(0, 12) SBC.Parent = Sidebar
    local SBDiv = Instance.new("Frame")
    SBDiv.Size = UDim2.new(0, 1, 1, 0); SBDiv.Position = UDim2.new(1, -1, 0, 0)
    SBDiv.BackgroundColor3 = Config.Border; SBDiv.BackgroundTransparency = 0.85
    SBDiv.BorderSizePixel = 0; SBDiv.Parent = Sidebar

    local UB = Instance.new("Frame")
    UB.Size = UDim2.new(1, -12, 0, 36); UB.Position = UDim2.new(0, 6, 0, 8)
    UB.BackgroundColor3 = Config.BgCard; UB.BackgroundTransparency = 0.6
    UB.BorderSizePixel = 0; UB.Parent = Sidebar
    local UBC = Instance.new("UICorner") UBC.CornerRadius = UDim.new(0, 6) UBC.Parent = UB

    local UAvatar = Instance.new("Frame")
    UAvatar.Size = UDim2.new(0, 24, 0, 24); UAvatar.Position = UDim2.new(0, 6, 0.5, -12)
    UAvatar.BackgroundColor3 = Config.Accent; UAvatar.BorderSizePixel = 0; UAvatar.Parent = UB
    local UAC = Instance.new("UICorner") UAC.CornerRadius = UDim.new(1, 0) UAC.Parent = UAvatar

    local UI2 = Instance.new("TextLabel")
    UI2.Size = UDim2.new(1, 0, 1, 0); UI2.BackgroundTransparency = 1
    UI2.Text = string.sub(LocalPlayer.Name, 1, 1):upper()
    UI2.TextColor3 = Config.TextPrimary; UI2.TextSize = 12; UI2.Font = Enum.Font.GothamBold; UI2.Parent = UAvatar

    local UN = Instance.new("TextLabel")
    UN.Size = UDim2.new(1, -38, 0, 12); UN.Position = UDim2.new(0, 36, 0, 6)
    UN.BackgroundTransparency = 1; UN.Text = LocalPlayer.Name
    UN.TextColor3 = Config.TextPrimary; UN.TextSize = 10; UN.Font = Enum.Font.GothamBold
    UN.TextXAlignment = Enum.TextXAlignment.Left; UN.TextTruncate = Enum.TextTruncate.AtEnd; UN.Parent = UB

    local US = Instance.new("TextLabel")
    US.Size = UDim2.new(1, -38, 0, 10); US.Position = UDim2.new(0, 36, 0, 20)
    US.BackgroundTransparency = 1; US.Text = "● Verified"
    US.TextColor3 = Config.Success; US.TextSize = 8; US.Font = Enum.Font.GothamMedium
    US.TextXAlignment = Enum.TextXAlignment.Left; US.Parent = UB

    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -158, 1, -48); Content.Position = UDim2.new(0, 158, 0, 40)
    Content.BackgroundColor3 = Config.BgContent; Content.BorderSizePixel = 0; Content.Parent = Main
    local CC2 = Instance.new("UICorner") CC2.CornerRadius = UDim.new(0, 12) CC2.Parent = Content

    local PageTitle = Instance.new("TextLabel")
    PageTitle.Size = UDim2.new(1, -16, 0, 22); PageTitle.Position = UDim2.new(0, 8, 0, 2)
    PageTitle.BackgroundTransparency = 1; PageTitle.Text = "BYPASS"
    PageTitle.TextColor3 = Config.TextPrimary; PageTitle.TextSize = 14; PageTitle.Font = Enum.Font.GothamBlack
    PageTitle.TextXAlignment = Enum.TextXAlignment.Left; PageTitle.Parent = Content

    local PageLine = Instance.new("Frame")
    PageLine.Size = UDim2.new(1, -16, 0, 1); PageLine.Position = UDim2.new(0, 8, 0, 26)
    PageLine.BackgroundColor3 = Config.Accent; PageLine.BorderSizePixel = 0; PageLine.Parent = Content

    local PageHolder = Instance.new("Frame")
    PageHolder.Size = UDim2.new(1, -16, 1, -34); PageHolder.Position = UDim2.new(0, 8, 0, 32)
    PageHolder.BackgroundTransparency = 1; PageHolder.Parent = Content

    local Page = Instance.new("ScrollingFrame")
    Page.Size = UDim2.new(1, 0, 1, 0); Page.BackgroundTransparency = 1; Page.BorderSizePixel = 0
    Page.ScrollBarThickness = 3; Page.ScrollBarImageColor3 = Config.Accent
    Page.ScrollBarImageTransparency = 0.5
    Page.CanvasSize = UDim2.new(0, 0, 0, 0); Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.Parent = PageHolder
    local PL = Instance.new("UIListLayout") PL.Padding = UDim.new(0, 5) PL.SortOrder = Enum.SortOrder.LayoutOrder PL.Parent = Page
    local PP = Instance.new("UIPadding") PP.PaddingTop = UDim.new(0, 4) PP.PaddingBottom = UDim.new(0, 4) PP.Parent = Page

    local function createSection(parent, text)
        local Sec = Instance.new("Frame")
        Sec.Size = UDim2.new(1, 0, 0, 20); Sec.BackgroundTransparency = 1; Sec.Parent = parent
        local Icon = Instance.new("TextLabel")
        Icon.Size = UDim2.new(0, 14, 0, 14); Icon.Position = UDim2.new(0, 2, 0.5, -7)
        Icon.BackgroundTransparency = 1; Icon.Text = "✦"
        Icon.TextColor3 = Config.Accent; Icon.TextSize = 10; Icon.Font = Enum.Font.GothamBold; Icon.Parent = Sec
        local L = Instance.new("TextLabel")
        L.Size = UDim2.new(1, -22, 1, 0); L.Position = UDim2.new(0, 20, 0, 0)
        L.BackgroundTransparency = 1; L.Text = text
        L.TextColor3 = Config.TextSecond; L.TextSize = 10; L.Font = Enum.Font.GothamBold
        L.TextXAlignment = Enum.TextXAlignment.Left; L.Parent = Sec
    end

    local function createToggle(parent, text, default, callback)
        local Card = Instance.new("Frame")
        Card.Size = UDim2.new(1, 0, 0, 32); Card.BackgroundColor3 = Config.BgCard
        Card.BackgroundTransparency = 0.4; Card.BorderSizePixel = 0; Card.Parent = parent
        local C = Instance.new("UICorner") C.CornerRadius = UDim.new(0, 6) C.Parent = Card
        local CS = Instance.new("UIStroke") CS.Color = Config.Border CS.Thickness = 1 CS.Transparency = 0.92 CS.Parent = Card
        local L = Instance.new("TextLabel")
        L.Size = UDim2.new(1, -55, 1, 0); L.Position = UDim2.new(0, 10, 0, 0)
        L.BackgroundTransparency = 1; L.Text = text
        L.TextColor3 = Config.TextPrimary; L.TextSize = 10; L.Font = Enum.Font.Gotham
        L.TextXAlignment = Enum.TextXAlignment.Left; L.Parent = Card
        local TB = Instance.new("Frame")
        TB.Size = UDim2.new(0, 30, 0, 16); TB.Position = UDim2.new(1, -40, 0.5, -8)
        TB.BackgroundColor3 = default and Config.Accent or Color3.fromRGB(60,60,72)
        TB.BorderSizePixel = 0; TB.Parent = Card
        local TBC2 = Instance.new("UICorner") TBC2.CornerRadius = UDim.new(1, 0) TBC2.Parent = TB
        local TBtn = Instance.new("TextButton")
        TBtn.Size = UDim2.new(1, 0, 1, 0); TBtn.BackgroundTransparency = 1; TBtn.Text = ""; TBtn.Parent = TB
        local K = Instance.new("Frame")
        K.Size = UDim2.new(0, 12, 0, 12)
        K.Position = default and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
        K.BackgroundColor3 = Color3.fromRGB(255,255,255); K.BorderSizePixel = 0; K.Parent = TB
        local KC = Instance.new("UICorner") KC.CornerRadius = UDim.new(1, 0) KC.Parent = K
        local isOn = default
        TBtn.MouseButton1Click:Connect(function()
            isOn = not isOn
            TweenService:Create(TB, TweenInfo.new(0.15), { BackgroundColor3 = isOn and Config.Accent or Color3.fromRGB(60,60,72) }):Play()
            TweenService:Create(K, TweenInfo.new(0.15), { Position = isOn and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6) }):Play()
            if callback then callback(isOn) end
        end)
    end

    local function createSlider(parent, text, min, max, default, suffix, callback)
        local Card = Instance.new("Frame")
        Card.Size = UDim2.new(1, 0, 0, 44); Card.BackgroundColor3 = Config.BgCard
        Card.BackgroundTransparency = 0.4; Card.BorderSizePixel = 0; Card.Parent = parent
        local C = Instance.new("UICorner") C.CornerRadius = UDim.new(0, 6) C.Parent = Card
        local CS = Instance.new("UIStroke") CS.Color = Config.Border CS.Thickness = 1 CS.Transparency = 0.92 CS.Parent = Card
        local L = Instance.new("TextLabel")
        L.Size = UDim2.new(1, -80, 0, 12); L.Position = UDim2.new(0, 10, 0, 6)
        L.BackgroundTransparency = 1; L.Text = text
        L.TextColor3 = Config.TextPrimary; L.TextSize = 10; L.Font = Enum.Font.Gotham
        L.TextXAlignment = Enum.TextXAlignment.Left; L.Parent = Card
        local VL = Instance.new("TextLabel")
        VL.Size = UDim2.new(0, 70, 0, 12); VL.Position = UDim2.new(1, -80, 0, 6)
        VL.BackgroundTransparency = 1; VL.Text = tostring(default) .. " " .. (suffix or "")
        VL.TextColor3 = Config.TextSecond; VL.TextSize = 10; VL.Font = Enum.Font.GothamBold
        VL.TextXAlignment = Enum.TextXAlignment.Right; VL.Parent = Card
        local Bar = Instance.new("Frame")
        Bar.Size = UDim2.new(1, -20, 0, 3); Bar.Position = UDim2.new(0, 10, 0, 30)
        Bar.BackgroundColor3 = Color3.fromRGB(60,60,72); Bar.BorderSizePixel = 0; Bar.Parent = Card
        local BC = Instance.new("UICorner") BC.CornerRadius = UDim.new(1, 0) BC.Parent = Bar
        local Fill = Instance.new("Frame")
        Fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
        Fill.BackgroundColor3 = Config.Accent; Fill.BorderSizePixel = 0; Fill.Parent = Bar
        local FC = Instance.new("UICorner") FC.CornerRadius = UDim.new(1, 0) FC.Parent = Fill
        local Dot = Instance.new("Frame")
        Dot.Size = UDim2.new(0, 11, 0, 11)
        Dot.Position = UDim2.new((default-min)/(max-min), -5.5, 0.5, -5.5)
        Dot.BackgroundColor3 = Color3.fromRGB(255,255,255); Dot.BorderSizePixel = 0; Dot.Parent = Bar
        local DC = Instance.new("UICorner") DC.CornerRadius = UDim.new(1, 0) DC.Parent = Dot
        local dragging = false
        local function update(input)
            local pos = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
            local v = math.floor(min + (max - min) * pos)
            Fill.Size = UDim2.new(pos, 0, 1, 0)
            Dot.Position = UDim2.new(pos, -5.5, 0.5, -5.5)
            VL.Text = tostring(v) .. " " .. (suffix or "")
            if callback then callback(v) end
        end
        Dot.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input) end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
        Bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                update(input); dragging = true
            end
        end)
    end

    local function createButton(parent, text, callback, isAccent)
        local B = Instance.new("TextButton")
        B.Size = UDim2.new(1, 0, 0, 30)
        B.BackgroundColor3 = isAccent and Config.Accent or Config.BgCard
        B.BackgroundTransparency = isAccent and 0 or 0.4
        B.Text = text; B.TextColor3 = Config.TextPrimary; B.TextSize = 10
        B.Font = Enum.Font.GothamBold; B.BorderSizePixel = 0; B.AutoButtonColor = false; B.Parent = parent
        local BC = Instance.new("UICorner") BC.CornerRadius = UDim.new(0, 6) BC.Parent = B
        local BS = Instance.new("UIStroke") BS.Color = isAccent and Config.Accent or Config.Border
        BS.Thickness = 1; BS.Transparency = isAccent and 0.4 or 0.92; BS.Parent = B
        B.MouseEnter:Connect(function()
            TweenService:Create(B, TweenInfo.new(0.15), { BackgroundColor3 = isAccent and Config.AccentHover or Config.BgHover, BackgroundTransparency = isAccent and 0 or 0.2 }):Play()
        end)
        B.MouseLeave:Connect(function()
            TweenService:Create(B, TweenInfo.new(0.15), { BackgroundColor3 = isAccent and Config.Accent or Config.BgCard, BackgroundTransparency = isAccent and 0 or 0.4 }):Play()
        end)
        B.MouseButton1Click:Connect(function() if callback then callback() end end)
    end

    local function createTextInput(parent, text, placeholder, default, callback)
        local Card = Instance.new("Frame")
        Card.Size = UDim2.new(1, 0, 0, 42); Card.BackgroundColor3 = Config.BgCard
        Card.BackgroundTransparency = 0.4; Card.BorderSizePixel = 0; Card.Parent = parent
        local C = Instance.new("UICorner") C.CornerRadius = UDim.new(0, 6) C.Parent = Card
        local CS = Instance.new("UIStroke") CS.Color = Config.Border CS.Thickness = 1 CS.Transparency = 0.92 CS.Parent = Card
        local L = Instance.new("TextLabel")
        L.Size = UDim2.new(1, -20, 0, 12); L.Position = UDim2.new(0, 10, 0, 4)
        L.BackgroundTransparency = 1; L.Text = text
        L.TextColor3 = Config.TextPrimary; L.TextSize = 10; L.Font = Enum.Font.Gotham
        L.TextXAlignment = Enum.TextXAlignment.Left; L.Parent = Card
        local Box = Instance.new("TextBox")
        Box.Size = UDim2.new(1, -20, 0, 20); Box.Position = UDim2.new(0, 10, 0, 18)
        Box.BackgroundColor3 = Color3.fromRGB(22,22,28); Box.BorderSizePixel = 0
        Box.Text = default or ""; Box.PlaceholderText = placeholder or ""
        Box.TextColor3 = Config.TextPrimary; Box.PlaceholderColor3 = Config.TextMuted
        Box.TextSize = 10; Box.Font = Enum.Font.GothamBold
        Box.TextXAlignment = Enum.TextXAlignment.Left; Box.ClearTextOnFocus = false; Box.Parent = Card
        local BC = Instance.new("UICorner") BC.CornerRadius = UDim.new(0, 4) BC.Parent = Box
        local BP = Instance.new("UIPadding") BP.PaddingLeft = UDim.new(0, 6) BP.Parent = Box
        Box.FocusLost:Connect(function() if callback then callback(Box.Text) end end)
    end

    local function clearPage()
        for _, c in ipairs(Page:GetChildren()) do
            if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
        end
    end

    local bypassedGates = {}
    local bypassedCollisions = {}

    local function bypassAllGates()
        local count = 0
        local kw = {"gate","barrier","wall","door","block","lock","required","rebirth","level","quest","unlock","invisible","region","zone","portal"}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local n = string.lower(obj.Name)
                for _, k in ipairs(kw) do
                    if string.find(n, k) then
                        pcall(function()
                            obj.CanCollide = false; obj.CanTouch = false; obj.CanQuery = false
                            obj.Transparency = 1; obj.Massless = true
                            if not bypassedGates[obj] then bypassedGates[obj] = true; count = count + 1 end
                        end)
                        break
                    end
                end
            elseif obj:IsA("Model") then
                local n = string.lower(obj.Name)
                for _, k in ipairs(kw) do
                    if string.find(n, k) then
                        for _, p in ipairs(obj:GetDescendants()) do
                            if p:IsA("BasePart") then
                                pcall(function()
                                    p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
                                    p.Transparency = 1; p.Massless = true
                                end)
                            end
                        end
                        count = count + 1; break
                    end
                end
            end
        end
        return count
    end

    local function disableGateChecks()
        local c = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("Model") then
                local n = string.lower(obj.Name)
                if string.find(n, "barrier") or string.find(n, "gate") or string.find(n, "door") or string.find(n, "block") then
                    for _, s in ipairs(obj:GetDescendants()) do
                        if s:IsA("Script") or s:IsA("LocalScript") then
                            pcall(function() s.Disabled = true end); c = c + 1
                        end
                    end
                end
            end
        end
        return c
    end

    local function bypassAllPrompts()
        local c = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                pcall(function()
                    obj.HoldDuration = 0; obj.MaxActivationDistance = 9999
                    obj.RequiresLineOfSight = false; obj.Enabled = true
                end)
                c = c + 1
            end
        end
        return c
    end

    local function activateAllPrompts()
        local c = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                pcall(function()
                    obj.HoldDuration = 0; obj.MaxActivationDistance = 9999
                    obj.RequiresLineOfSight = false
                    if fireproximityprompt then fireproximityprompt(obj); c = c + 1 end
                end)
            end
        end
        return c
    end

    local function disableAllCollision()
        local c = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.CanCollide then
                if not LocalPlayer.Character or not obj:IsDescendantOf(LocalPlayer.Character) then
                    pcall(function()
                        bypassedCollisions[obj] = obj.CanCollide; obj.CanCollide = false; c = c + 1
                    end)
                end
            end
        end
        return c
    end

    local function restoreAllCollision()
        for obj, v in pairs(bypassedCollisions) do
            if obj and obj.Parent then pcall(function() obj.CanCollide = v end) end
        end
        bypassedCollisions = {}
    end

    local function teleportThroughGate()
        local char = LocalPlayer.Character
        if not char then return false end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        local nearest, shortest = nil, State.BypassRange
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local n = string.lower(obj.Name)
                if string.find(n, "gate") or string.find(n, "barrier") or string.find(n, "door") or string.find(n, "wall") then
                    local d = (obj.Position - hrp.Position).Magnitude
                    if d < shortest then shortest = d; nearest = obj end
                end
            end
        end
        if nearest then
            local fwd = (nearest.Position - hrp.Position).Unit
            pcall(function() hrp.CFrame = CFrame.new(nearest.Position + fwd * 20) end)
            return true
        end
        return false
    end

    local function cleanupSpeedInstances()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        for _, n in ipairs({"SpeedBV", "FlyBV", "FlyBG", "AntiFlingBV"}) do
            local o = hrp:FindFirstChild(n)
            if o then pcall(function() o:Destroy() end) end
        end
    end

    local function resetCharacterPhysics()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum.WalkSpeed = 16 end)
            pcall(function() hum.JumpPower = 50 end)
            pcall(function() hum.PlatformStand = false end)
        end
        cleanupSpeedInstances()
    end

    local Tabs = {}
    local ActiveTab = "Bypass"

    local tabDefs = {
        {name = "Bypass",    icon = "🔒"},
        {name = "Movement",  icon = "🏃"},
        {name = "Save/TP",   icon = "📍"},
        {name = "Anti-Ban",  icon = "🛡️"},
        {name = "Settings",  icon = "⚙️"},
    }

    for i, def in ipairs(tabDefs) do
        local Tab = Instance.new("TextButton")
        Tab.Size = UDim2.new(1, -12, 0, 30)
        Tab.Position = UDim2.new(0, 6, 0, 56 + ((i-1) * 34))
        Tab.BackgroundColor3 = Color3.fromRGB(255,255,255); Tab.BackgroundTransparency = 1
        Tab.Text = "  " .. def.icon .. "  " .. def.name
        Tab.TextColor3 = Config.TextSecond; Tab.TextSize = 11; Tab.Font = Enum.Font.GothamBold
        Tab.TextXAlignment = Enum.TextXAlignment.Left; Tab.BorderSizePixel = 0
        Tab.AutoButtonColor = false; Tab.Parent = Sidebar
        local TC = Instance.new("UICorner") TC.CornerRadius = UDim.new(0, 6) TC.Parent = Tab
        local Ind = Instance.new("Frame")
        Ind.Size = UDim2.new(0, 2, 0.55, 0); Ind.Position = UDim2.new(0, 0, 0.225, 0)
        Ind.BackgroundColor3 = Config.Accent; Ind.BorderSizePixel = 0; Ind.Visible = false; Ind.Parent = Tab
        local IndC = Instance.new("UICorner") IndC.CornerRadius = UDim.new(1, 0) IndC.Parent = Ind

        Tabs[def.name] = { Button = Tab, Indicator = Ind }

        Tab.MouseButton1Click:Connect(function()
            for _, t in pairs(Tabs) do
                t.Button.BackgroundTransparency = 1
                t.Button.TextColor3 = Config.TextSecond
                t.Indicator.Visible = false
            end
            Tab.BackgroundTransparency = 0.5
            Tab.TextColor3 = Config.TextPrimary
            Ind.Visible = true
            ActiveTab = def.name
            PageTitle.Text = string.upper(def.name)

            clearPage()
            if def.name == "Bypass" then
                createSection(Page, "Bypass Gate System")
                createToggle(Page, "Bypass All Gates", State.BypassEnabled, function(v) State.BypassEnabled = v; if v then bypassAllGates() end end)
                createSlider(Page, "Bypass Range", 50, 1000, State.BypassRange, "studs", function(v) State.BypassRange = v end)
                createToggle(Page, "Remove All Collision", State.RemoveCollision, function(v) State.RemoveCollision = v; if v then disableAllCollision() else restoreAllCollision() end end)
                createToggle(Page, "Auto Enter Locked Zones", State.AutoEnterLocked, function(v) State.AutoEnterLocked = v end)
                createSection(Page, "Quick Actions")
                createButton(Page, "🚪 Bypass All Now", function()
                    local a = bypassAllGates(); local b = disableGateChecks(); local c = bypassAllPrompts()
                    print("[BYPASS] G:" .. a .. " C:" .. b .. " P:" .. c)
                end, true)
                createButton(Page, "🔓 Activate All Prompts", function() activateAllPrompts() end)
                createButton(Page, "🚀 Teleport Through Gate", function() teleportThroughGate() end)
                createButton(Page, "🧹 Restore All Gates", function()
                    for obj in pairs(bypassedGates) do
                        if obj and obj.Parent then
                            pcall(function() obj.CanCollide = true; obj.CanTouch = true; obj.CanQuery = true; obj.Transparency = 0 end)
                        end
                    end
                    bypassedGates = {}; restoreAllCollision()
                end)
            elseif def.name == "Movement" then
                createSection(Page, "Speed")
                createToggle(Page, "Speed Hack", State.SpeedEnabled, function(v) State.SpeedEnabled = v end)
                createSlider(Page, "Speed Value", 16, 500, State.SpeedValue, "WS", function(v) State.SpeedValue = v end)
                createSlider(Page, "Max Speed Cap", 50, 500, State.MaxSpeed, "WS", function(v) State.MaxSpeed = v end)
                createSection(Page, "Fly")
                createToggle(Page, "Fly", State.FlyEnabled, function(v) State.FlyEnabled = v end)
                createSlider(Page, "Fly Speed", 30, 300, State.FlySpeed, "studs", function(v) State.FlySpeed = v end)
                createSection(Page, "Extras")
                createToggle(Page, "Noclip", State.NoclipEnabled, function(v) State.NoclipEnabled = v end)
                createToggle(Page, "Infinite Jump", State.InfJumpEnabled, function(v) State.InfJumpEnabled = v end)
                createToggle(Page, "Anti-Fling", State.AntiFlingEnabled, function(v) State.AntiFlingEnabled = v end)
                createToggle(Page, "Anti-Void", State.AntiVoidEnabled, function(v) State.AntiVoidEnabled = v end)
                createToggle(Page, "Anti-AFK", State.AntiAfkEnabled, function(v) State.AntiAfkEnabled = v end)
            elseif def.name == "Save/TP" then
                createSection(Page, "Save Position")
                createTextInput(Page, "Save Name", "e.g. base", "spot1", function(v) State.SaveName = v end)
                createButton(Page, "💾 Save Current Position", function()
                    local char = LocalPlayer.Character
                    if not char then return end
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    State.SavedPositions[State.SaveName or "spot1"] = { x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z }
                end, true)
                createSection(Page, "Teleport to XYZ")
                createTextInput(Page, "Coordinates (x, y, z)", "0, 50, 0", "0, 50, 0", function(v) State.XYZ = v end)
                createButton(Page, "📍 Teleport to XYZ", function()
                    local coords = {}
                    for n in string.gmatch(State.XYZ or "0,50,0", "[^,%s]+") do table.insert(coords, tonumber(n)) end
                    if #coords == 3 then
                        local char = LocalPlayer.Character
                        if char then
                            local hrp = char:FindFirstChild("HumanoidRootPart")
                            if hrp then hrp.CFrame = CFrame.new(Vector3.new(coords[1], coords[2], coords[3])) end
                        end
                    end
                end, true)
                createSection(Page, "Quick Actions")
                createButton(Page, "🏠 Teleport to Spawn", function()
                    local spawn = Workspace:FindFirstChildOfClass("SpawnLocation")
                    if spawn then
                        local char = LocalPlayer.Character
                        if char then
                            local hrp = char:FindFirstChild("HumanoidRootPart")
                            if hrp then hrp.CFrame = CFrame.new(spawn.Position + Vector3.new(0, 5, 0)) end
                        end
                    end
                end)
                createButton(Page, "🔝 Teleport Up (+50Y)", function()
                    local char = LocalPlayer.Character
                    if char then
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hrp then hrp.CFrame = hrp.CFrame + Vector3.new(0, 50, 0) end
                    end
                end)
            elseif def.name == "Anti-Ban" then
                createSection(Page, "Core")
                createToggle(Page, "Anti-Ban System", State.AntiBanEnabled, function(v) State.AntiBanEnabled = v end)
                createToggle(Page, "Jitter ±2", State.JitterEnabled, function(v) State.JitterEnabled = v end)
                createToggle(Page, "Rate Limit 20Hz", State.RateLimitEnabled, function(v) State.RateLimitEnabled = v end)
                createToggle(Page, "Ramp Up Smooth", State.RampUpEnabled, function(v) State.RampUpEnabled = v end)
                createToggle(Page, "Legit Mode (60)", State.LegitMode, function(v) State.LegitMode = v end)
                createSection(Page, "Emergency")
                createButton(Page, "🧹 Panic Cleanup", function()
                    resetCharacterPhysics()
                    State.SpeedEnabled = false; State.FlyEnabled = false; State.NoclipEnabled = false
                    State.BypassEnabled = false; State.RemoveCollision = false
                    AntiBan.currentRampSpeed = 16
                end, true)
                createButton(Page, "🔧 Reset Physics", function() resetCharacterPhysics() end)
                createSection(Page, "Diagnostics")
                createButton(Page, "🔄 Reload Script", function()
                    task.wait(1)
                    loadstring(game:HttpGet("https://raw.githubusercontent.com/alwayszoey/Excute-hub-open/refs/heads/main/main.lua"))()
                end, true)
            elseif def.name == "Settings" then
                createSection(Page, "Display")
                createToggle(Page, "Show Coordinate HUD", State.ShowCoords, function(v) State.ShowCoords = v end)
                createSection(Page, "Script")
                createButton(Page, "Rejoin Server", function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
                createButton(Page, "Unload Script", function()
                    resetCharacterPhysics()
                    ScreenGui:Destroy()
                end, true)
                createSection(Page, "About")
                createButton(Page, "Execute Hub " .. Config.Version, function() end)
            end
        end)
    end

    if Tabs["Bypass"] then
        Tabs["Bypass"].Button.BackgroundTransparency = 0.5
        Tabs["Bypass"].Button.TextColor3 = Config.TextPrimary
        Tabs["Bypass"].Indicator.Visible = true
    end

    do
        createSection(Page, "Bypass Gate System")
        createToggle(Page, "Bypass All Gates", State.BypassEnabled, function(v) State.BypassEnabled = v; if v then bypassAllGates() end end)
        createSlider(Page, "Bypass Range", 50, 1000, State.BypassRange, "studs", function(v) State.BypassRange = v end)
        createToggle(Page, "Remove All Collision", State.RemoveCollision, function(v) State.RemoveCollision = v; if v then disableAllCollision() else restoreAllCollision() end end)
        createToggle(Page, "Auto Enter Locked Zones", State.AutoEnterLocked, function(v) State.AutoEnterLocked = v end)
        createSection(Page, "Quick Actions")
        createButton(Page, "🚪 Bypass All Now", function()
            local a = bypassAllGates(); local b = disableGateChecks(); local c = bypassAllPrompts()
            print("[BYPASS] G:" .. a .. " C:" .. b .. " P:" .. c)
        end, true)
        createButton(Page, "🔓 Activate All Prompts", function() activateAllPrompts() end)
        createButton(Page, "🚀 Teleport Through Gate", function() teleportThroughGate() end)
        createButton(Page, "🧹 Restore All Gates", function()
            for obj in pairs(bypassedGates) do
                if obj and obj.Parent then
                    pcall(function() obj.CanCollide = true; obj.CanTouch = true; obj.CanQuery = true; obj.Transparency = 0 end)
                end
            end
            bypassedGates = {}; restoreAllCollision()
        end)
    end

    CloseBtn.MouseButton1Click:Connect(function() resetCharacterPhysics(); ScreenGui:Destroy() end)
    local minimized = false
    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            Main.Size = UDim2.new(0, 600, 0, 40)
            Sidebar.Visible = false; Content.Visible = false
        else
            Main.Size = UDim2.new(0, 600, 0, 400)
            Sidebar.Visible = true; Content.Visible = true
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightControl then Main.Visible = not Main.Visible end
    end)

    local CoordGui = Instance.new("ScreenGui")
    CoordGui.Name = "ExecuteHubHUD"
    CoordGui.ResetOnSpawn = false
    CoordGui.IgnoreGuiInset = true
    pcall(function() CoordGui.Parent = CoreGui end)
    if not CoordGui.Parent then CoordGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local CoordHUD = Instance.new("Frame")
    CoordHUD.Size = UDim2.new(0, 190, 0, 62); CoordHUD.Position = UDim2.new(1, -200, 0, 60)
    CoordHUD.BackgroundColor3 = Config.BgCard; CoordHUD.BackgroundTransparency = 0.2
    CoordHUD.BorderSizePixel = 0; CoordHUD.Active = true; CoordHUD.Draggable = true; CoordHUD.Parent = CoordGui
    local CHC = Instance.new("UICorner") CHC.CornerRadius = UDim.new(0, 8) CHC.Parent = CoordHUD
    local CHS = Instance.new("UIStroke") CHS.Color = Config.Accent CHS.Thickness = 1 CHS.Transparency = 0.5 CHS.Parent = CoordHUD

    local CoordTitle = Instance.new("TextLabel")
    CoordTitle.Size = UDim2.new(1, -12, 0, 14); CoordTitle.Position = UDim2.new(0, 6, 0, 4)
    CoordTitle.BackgroundTransparency = 1; CoordTitle.Text = "📍 POSITION"
    CoordTitle.TextColor3 = Config.Accent; CoordTitle.TextSize = 9; CoordTitle.Font = Enum.Font.GothamBold
    CoordTitle.TextXAlignment = Enum.TextXAlignment.Left; CoordTitle.Parent = CoordHUD

    local CoordText = Instance.new("TextLabel")
    CoordText.Size = UDim2.new(1, -12, 0, 18); CoordText.Position = UDim2.new(0, 6, 0, 18)
    CoordText.BackgroundTransparency = 1; CoordText.Text = "X: 0.0   Y: 0.0\nZ: 0.0"
    CoordText.TextColor3 = Config.TextPrimary; CoordText.TextSize = 10; CoordText.Font = Enum.Font.Code
    CoordText.TextXAlignment = Enum.TextXAlignment.Left; CoordText.TextYAlignment = Enum.TextYAlignment.Top
    CoordText.Parent = CoordHUD

    local StatsText = Instance.new("TextLabel")
    StatsText.Size = UDim2.new(1, -12, 0, 12); StatsText.Position = UDim2.new(0, 6, 0, 44)
    StatsText.BackgroundTransparency = 1; StatsText.Text = "FPS: --"
    StatsText.TextColor3 = Config.TextSecond; StatsText.TextSize = 9; StatsText.Font = Enum.Font.Code
    StatsText.TextXAlignment = Enum.TextXAlignment.Left; StatsText.Parent = CoordHUD

    task.spawn(function()
        while task.wait(0.1) do
            CoordHUD.Visible = State.ShowCoords
            if State.ShowCoords then
                local char = LocalPlayer.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local p = hrp.Position
                        CoordText.Text = string.format("X: %.1f   Y: %.1f\nZ: %.1f", p.X, p.Y, p.Z)
                    end
                end
            end
        end
    end)

    task.spawn(function()
        local c, t = 0, 0
        RunService.RenderStepped:Connect(function(dt)
            c = c + 1; t = t + dt
            if t >= 0.5 then
                StatsText.Text = string.format("FPS: %d", math.floor(c/t))
                c = 0; t = 0
            end
        end)
    end)

    RunService.RenderStepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end
        if State.SpeedEnabled then
            if State.RateLimitEnabled then
                AntiBan.tickCounter = (AntiBan.tickCounter + 1) % 3
                if AntiBan.tickCounter ~= 0 then return end
            end
            local target = State.SpeedValue
            if State.LegitMode then target = math.min(target, 60) end
            if target > State.MaxSpeed then target = State.MaxSpeed end
            if State.RampUpEnabled then
                local d = target - AntiBan.currentRampSpeed
                if math.abs(d) > 0.5 then
                    AntiBan.currentRampSpeed = AntiBan.currentRampSpeed + d * 0.05
                    target = math.floor(AntiBan.currentRampSpeed)
                else AntiBan.currentRampSpeed = target end
            end
            local sp = target
            if State.JitterEnabled then
                local j = math.random(-2, 2)
                if math.random(1, 10) == 1 then j = 0 end
                sp = target + j
            end
            pcall(function() hum.WalkSpeed = sp end)
            if hum.MoveDirection.Magnitude > 0.1 then
                local dir = hum.MoveDirection
                pcall(function() hrp.Velocity = Vector3.new(dir.X * sp, hrp.Velocity.Y, dir.Z * sp) end)
            else
                pcall(function() hrp.Velocity = Vector3.new(0, hrp.Velocity.Y, 0) end)
            end
            local bv = hrp:FindFirstChild("SpeedBV")
            if not bv then
                bv = Instance.new("BodyVelocity")
                bv.Name = "SpeedBV"; bv.MaxForce = Vector3.new(math.huge, 0, math.huge); bv.Parent = hrp
            end
            if hum.MoveDirection.Magnitude > 0.1 then
                local dir = hum.MoveDirection
                bv.Velocity = Vector3.new(dir.X * sp, 0, dir.Z * sp)
            else bv.Velocity = Vector3.new(0, 0, 0) end
        else
            pcall(function() hum.WalkSpeed = 16 end)
            pcall(function() hrp.Velocity = Vector3.new(0, hrp.Velocity.Y, 0) end)
            local bv = hrp:FindFirstChild("SpeedBV")
            if bv then bv:Destroy() end
        end
    end)

    task.spawn(function() while task.wait(0.5) do cleanupSpeedInstances() end end)

    task.spawn(function()
        while task.wait(2) do
            if State.BypassEnabled then pcall(bypassAllGates); pcall(bypassAllPrompts) end
            if State.RemoveCollision then pcall(disableAllCollision) end
        end
    end)

    task.spawn(function()
        while task.wait(3) do
            if State.AutoEnterLocked and State.BypassEnabled then pcall(teleportThroughGate) end
        end
    end)

    task.spawn(function()
        while task.wait(0.1) do
            local char = LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if State.AntiFlingEnabled and hrp then
                    pcall(function() hrp.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 1, 1) end)
                end
                if State.AntiVoidEnabled and hrp and hrp.Position.Y < -50 then
                    pcall(function() hrp.CFrame = CFrame.new(0, 50, 0) end)
                end
            end
        end
    end)

    task.spawn(function()
        while task.wait(0.2) do
            if State.NoclipEnabled then
                local char = LocalPlayer.Character
                if char then
                    for _, p in ipairs(char:GetDescendants()) do
                        if p:IsA("BasePart") then pcall(function() p.CanCollide = false end) end
                    end
                end
            end
        end
    end)

    local flyConn, flyCleanup
    local function startFly()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        local oldBV = hrp:FindFirstChild("FlyBV"); if oldBV then oldBV:Destroy() end
        local oldBG = hrp:FindFirstChild("FlyBG"); if oldBG then oldBG:Destroy() end
        local bv = Instance.new("BodyVelocity")
        bv.Name = "FlyBV"; bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.new(0, 0, 0); bv.Parent = hrp
        local bg = Instance.new("BodyGyro")
        bg.Name = "FlyBG"; bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.P = 10000; bg.D = 500; bg.Parent = hrp
        hum.PlatformStand = true
        flyConn = RunService.RenderStepped:Connect(function()
            local cam = workspace.CurrentCamera
            if not cam then return end
            local dir = Vector3.new(0, 0, 0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
            local sp = State.FlySpeed or 60
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then sp = sp * 2 end
            bv.Velocity = dir * sp
            bg.CFrame = cam.CFrame
        end)
        flyCleanup = function()
            if flyConn then flyConn:Disconnect(); flyConn = nil end
            if bv and bv.Parent then bv:Destroy() end
            if bg and bg.Parent then bg:Destroy() end
            if hum then hum.PlatformStand = false end
        end
    end

    RunService.Heartbeat:Connect(function()
        if State.FlyEnabled and not flyConn then startFly()
        elseif not State.FlyEnabled and flyConn then
            if flyCleanup then flyCleanup() end
        end
    end)

    UserInputService.JumpRequest:Connect(function()
        if State.InfJumpEnabled then
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end
        end
    end)

    LocalPlayer.Idled:Connect(function()
        if State.AntiAfkEnabled then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if flyCleanup then flyCleanup(); flyConn = nil; flyCleanup = nil end
        AntiBan.currentRampSpeed = 16
        task.wait(2)
        if State.BypassEnabled then pcall(bypassAllGates); pcall(bypassAllPrompts) end
    end)

    print("[EXECUTE HUB] " .. Config.Version .. " loaded (verified)")
end

-- ============================================================
-- ENTRY POINT
-- ============================================================
local function tryStoredKey()
    if not (readfile and isfile) then return nil end
    local ok, content = pcall(function()
        return readfile(STORAGE_KEY .. ".txt")
    end)
    if ok and content and #content > 8 then
        return content
    end
    return nil
end

local function startVerifyFlow()
    local stored = tryStoredKey()

    if stored then
        local valid = verifyKey(stored)
        if valid then
            buildMainUI()
            return
        end
    end

    buildVerifyScreen(function()
        buildMainUI()
    end)
end

startVerifyFlow()
