-- ============================================================
-- GETKEY UI - v1.0.0
-- Discord-style Key Verification Screen
-- ============================================================

local GetkeyUI = {}

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")
local HttpService      = game:GetService("HttpService")
local RbxAnalytics     = game:GetService("RbxAnalyticsService")
local LocalPlayer      = Players.LocalPlayer

-- ============================================================
-- CONFIG
-- ============================================================
local Config = {
    Title = "UNIVERSAL HUB",
    Subtitle = "Official",
    Greeting = "Hello",
    ButtonText = "Paste your licence here.",
    VerifyText = "Verify Key",
    ApiUrl = "https://getkeyxcl.vercel.app",
    StorageKey = "universalhub_key_v1",
    -- Colors (Discord dark theme inspired)
    BgDark = Color3.fromRGB(6, 8, 14),
    BgCard = Color3.fromRGB(13, 16, 24),
    BgInput = Color3.fromRGB(20, 24, 34),
    Border = Color3.fromRGB(38, 45, 62),
    Accent = Color3.fromRGB(88, 132, 255),
    AccentHover = Color3.fromRGB(110, 150, 255),
    AccentGlow = Color3.fromRGB(80, 120, 255),
    TextPrimary = Color3.fromRGB(240, 244, 255),
    TextSecond = Color3.fromRGB(140, 150, 175),
    TextMuted = Color3.fromRGB(90, 100, 120),
    Success = Color3.fromRGB(80, 220, 130),
    Error = Color3.fromRGB(240, 100, 100)
}

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
-- VERIFY
-- ============================================================
local function verifyKey(key)
    local payload = HttpService:JSONEncode({ key = key, hwid = HWID })

    local ok, response = pcall(function()
        return HttpService:RequestAsync({
            Url = Config.ApiUrl .. "/api/key/verify",
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
-- BUILD UI
-- ============================================================
function GetkeyUI.Show(onSuccess)
    -- Cleanup old
    pcall(function()
        local old = CoreGui:FindFirstChild("GetkeyUI")
        if old then old:Destroy() end
    end)
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg and pg:FindFirstChild("GetkeyUI") then pg.GetkeyUI:Destroy() end
    end)

    local Gui = Instance.new("ScreenGui")
    Gui.Name = "GetkeyUI"
    Gui.ResetOnSpawn = false
    Gui.IgnoreGuiInset = true
    Gui.DisplayOrder = 999
    Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() Gui.Parent = CoreGui end)
    if not Gui.Parent then Gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    -- Backdrop
    local Backdrop = Instance.new("Frame")
    Backdrop.Name = "Backdrop"
    Backdrop.Size = UDim2.new(1, 0, 1, 0)
    Backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Backdrop.BackgroundTransparency = 0.4
    Backdrop.BorderSizePixel = 0
    Backdrop.ZIndex = 1
    Backdrop.Parent = Gui

    -- Main card
    local Card = Instance.new("Frame")
    Card.Name = "Card"
    Card.Size = UDim2.fromOffset(520, 380)
    Card.Position = UDim2.new(0.5, -260, 0.5, -190)
    Card.BackgroundColor3 = Config.BgCard
    Card.BackgroundTransparency = 0.02
    Card.BorderSizePixel = 0
    Card.Active = true
    Card.Draggable = true
    Card.ZIndex = 2
    Card.Parent = Gui
    local CardCorner = Instance.new("UICorner")
    CardCorner.CornerRadius = UDim.new(0, 12)
    CardCorner.Parent = Card
    local CardStroke = Instance.new("UIStroke")
    CardStroke.Color = Config.Border
    CardStroke.Thickness = 1
    CardStroke.Transparency = 0.3
    CardStroke.Parent = Card

    -- Subtle inner glow at top
    local Glow = Instance.new("Frame")
    Glow.Name = "Glow"
    Glow.Size = UDim2.new(1, -20, 0, 1)
    Glow.Position = UDim2.new(0, 10, 0, 0)
    Glow.BackgroundColor3 = Config.Accent
    Glow.BackgroundTransparency = 0.5
    Glow.BorderSizePixel = 0
    Glow.ZIndex = 3
    Glow.Parent = Card
    local GlowGrad = Instance.new("UIGradient")
    GlowGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.5, Config.Accent),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
    })
    GlowGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1, 1)
    })
    GlowGrad.Parent = Glow

    -- Title
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, -40, 0, 32)
    Title.Position = UDim2.new(0, 20, 0, 26)
    Title.BackgroundTransparency = 1
    Title.Text = Config.Title
    Title.TextColor3 = Config.TextPrimary
    Title.TextSize = 26
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Center
    Title.ZIndex = 3
    Title.Parent = Card

    -- Subtitle
    local Subtitle = Instance.new("TextLabel")
    Subtitle.Name = "Subtitle"
    Subtitle.Size = UDim2.new(1, -40, 0, 18)
    Subtitle.Position = UDim2.new(0, 20, 0, 58)
    Subtitle.BackgroundTransparency = 1
    Subtitle.Text = Config.Subtitle
    Subtitle.TextColor3 = Config.TextSecond
    Subtitle.TextSize = 13
    Subtitle.Font = Enum.Font.Gotham
    Subtitle.TextXAlignment = Enum.TextXAlignment.Center
    Subtitle.ZIndex = 3
    Subtitle.Parent = Card

    -- Divider under subtitle
    local Div = Instance.new("Frame")
    Div.Name = "Divider"
    Div.Size = UDim2.new(0, 60, 0, 1)
    Div.Position = UDim2.new(0.5, -30, 0, 80)
    Div.BackgroundColor3 = Config.Accent
    Div.BackgroundTransparency = 0.3
    Div.BorderSizePixel = 0
    Div.ZIndex = 3
    Div.Parent = Card

    -- Greeting
    local Greeting = Instance.new("TextLabel")
    Greeting.Name = "Greeting"
    Greeting.Size = UDim2.new(1, -40, 0, 18)
    Greeting.Position = UDim2.new(0, 20, 0, 98)
    Greeting.BackgroundTransparency = 1
    Greeting.Text = Config.Greeting .. ", " .. LocalPlayer.Name
    Greeting.TextColor3 = Config.TextSecond
    Greeting.TextSize = 12
    Greeting.Font = Enum.Font.Gotham
    Greeting.TextXAlignment = Enum.TextXAlignment.Center
    Greeting.ZIndex = 3
    Greeting.Parent = Card

    -- Input box
    local InputBox = Instance.new("Frame")
    InputBox.Name = "InputBox"
    InputBox.Size = UDim2.new(1, -60, 0, 40)
    InputBox.Position = UDim2.new(0, 30, 0, 128)
    InputBox.BackgroundColor3 = Config.BgInput
    InputBox.BorderSizePixel = 0
    InputBox.ZIndex = 3
    InputBox.Parent = Card
    local IB_Corner = Instance.new("UICorner")
    IB_Corner.CornerRadius = UDim.new(0, 6)
    IB_Corner.Parent = InputBox
    local IB_Stroke = Instance.new("UIStroke")
    IB_Stroke.Color = Config.Border
    IB_Stroke.Thickness = 1
    IB_Stroke.Parent = InputBox

    local Input = Instance.new("TextBox")
    Input.Name = "Input"
    Input.Size = UDim2.new(1, -24, 1, 0)
    Input.Position = UDim2.new(0, 12, 0, 0)
    Input.BackgroundTransparency = 1
    Input.Text = ""
    Input.PlaceholderText = Config.ButtonText
    Input.TextColor3 = Config.TextPrimary
    Input.PlaceholderColor3 = Config.TextMuted
    Input.TextSize = 12
    Input.Font = Enum.Font.Code
    Input.TextXAlignment = Enum.TextXAlignment.Center
    Input.ClearTextOnFocus = false
    Input.ZIndex = 4
    Input.Parent = InputBox

    -- Verify button
    local VerifyBtn = Instance.new("TextButton")
    VerifyBtn.Name = "VerifyBtn"
    VerifyBtn.Size = UDim2.new(1, -60, 0, 38)
    VerifyBtn.Position = UDim2.new(0, 30, 0, 178)
    VerifyBtn.BackgroundColor3 = Config.Accent
    VerifyBtn.Text = Config.VerifyText
    VerifyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    VerifyBtn.TextSize = 13
    VerifyBtn.Font = Enum.Font.GothamBold
    VerifyBtn.BorderSizePixel = 0
    VerifyBtn.AutoButtonColor = false
    VerifyBtn.ZIndex = 3
    VerifyBtn.Parent = Card
    local VB_Corner = Instance.new("UICorner")
    VB_Corner.CornerRadius = UDim.new(0, 6)
    VB_Corner.Parent = VerifyBtn

    -- Get Licence card (bottom)
    local LicenceCard = Instance.new("TextButton")
    LicenceCard.Name = "LicenceCard"
    LicenceCard.Size = UDim2.new(1, -60, 0, 62)
    LicenceCard.Position = UDim2.new(0, 30, 0, 232)
    LicenceCard.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
    LicenceCard.Text = ""
    LicenceCard.AutoButtonColor = false
    LicenceCard.BorderSizePixel = 0
    LicenceCard.ZIndex = 3
    LicenceCard.Parent = Card
    local LC_Corner = Instance.new("UICorner")
    LC_Corner.CornerRadius = UDim.new(0, 8)
    LC_Corner.Parent = LicenceCard
    local LC_Stroke = Instance.new("UIStroke")
    LC_Stroke.Color = Config.Border
    LC_Stroke.Thickness = 1
    LC_Stroke.Parent = LicenceCard

    -- Key icon
    local KeyIcon = Instance.new("ImageLabel")
    KeyIcon.Name = "KeyIcon"
    KeyIcon.Size = UDim2.fromOffset(28, 28)
    KeyIcon.Position = UDim2.new(0, 14, 0.5, -14)
    KeyIcon.BackgroundTransparency = 1
    KeyIcon.Image = "rbxassetid://10709791437"
    KeyIcon.ImageColor3 = Config.Accent
    KeyIcon.ZIndex = 4
    KeyIcon.Parent = LicenceCard

    -- Licence title
    local LicTitle = Instance.new("TextLabel")
    LicTitle.Name = "Title"
    LicTitle.Size = UDim2.new(1, -110, 0, 16)
    LicTitle.Position = UDim2.new(0, 52, 0, 12)
    LicTitle.BackgroundTransparency = 1
    LicTitle.Text = "Get Licence"
    LicTitle.TextColor3 = Config.TextPrimary
    LicTitle.TextSize = 14
    LicTitle.Font = Enum.Font.GothamBold
    LicTitle.TextXAlignment = Enum.TextXAlignment.Left
    LicTitle.ZIndex = 4
    LicTitle.Parent = LicenceCard

    -- Licence subtitle
    local LicSub = Instance.new("TextLabel")
    LicSub.Name = "Sub"
    LicSub.Size = UDim2.new(1, -110, 0, 28)
    LicSub.Position = UDim2.new(0, 52, 0, 28)
    LicSub.BackgroundTransparency = 1
    LicSub.Text = "Copy the key from our website, paste it above,\nand click verify to unlock the hub."
    LicSub.TextColor3 = Config.TextSecond
    LicSub.TextSize = 10
    LicSub.Font = Enum.Font.Gotham
    LicSub.TextXAlignment = Enum.TextXAlignment.Left
    LicSub.TextYAlignment = Enum.TextYAlignment.Top
    LicSub.TextWrapped = true
    LicSub.ZIndex = 4
    LicSub.Parent = LicenceCard

    -- Arrow
    local Arrow = Instance.new("TextLabel")
    Arrow.Name = "Arrow"
    Arrow.Size = UDim2.fromOffset(24, 24)
    Arrow.Position = UDim2.new(1, -34, 0.5, -12)
    Arrow.BackgroundTransparency = 1
    Arrow.Text = "›"
    Arrow.TextColor3 = Config.Accent
    Arrow.TextSize = 22
    Arrow.Font = Enum.Font.GothamBold
    Arrow.ZIndex = 4
    Arrow.Parent = LicenceCard

    -- Status label
    local Status = Instance.new("TextLabel")
    Status.Name = "Status"
    Status.Size = UDim2.new(1, -60, 0, 16)
    Status.Position = UDim2.new(0, 30, 0, 302)
    Status.BackgroundTransparency = 1
    Status.Text = "HWID: " .. string.sub(HWID, 1, 32) .. "..."
    Status.TextColor3 = Config.TextMuted
    Status.TextSize = 10
    Status.Font = Enum.Font.Code
    Status.TextXAlignment = Enum.TextXAlignment.Left
    Status.ZIndex = 3
    Status.Parent = Card

    -- Minimize button (top right)
    local MinBtn = Instance.new("TextButton")
    MinBtn.Name = "MinBtn"
    MinBtn.Size = UDim2.fromOffset(24, 24)
    MinBtn.Position = UDim2.new(1, -34, 0, 10)
    MinBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
    MinBtn.Text = "—"
    MinBtn.TextColor3 = Config.TextSecond
    MinBtn.TextSize = 14
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.BorderSizePixel = 0
    MinBtn.AutoButtonColor = false
    MinBtn.ZIndex = 3
    MinBtn.Parent = Card
    local MB_Corner = Instance.new("UICorner")
    MB_Corner.CornerRadius = UDim.new(0, 6)
    MB_Corner.Parent = MinBtn

    -- Close button
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "CloseBtn"
    CloseBtn.Size = UDim2.fromOffset(24, 24)
    CloseBtn.Position = UDim2.new(1, -62, 0, 10)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Config.TextSecond
    CloseBtn.TextSize = 12
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.BorderSizePixel = 0
    CloseBtn.AutoButtonColor = false
    CloseBtn.ZIndex = 3
    CloseBtn.Parent = Card
    local CB_Corner = Instance.new("UICorner")
    CB_Corner.CornerRadius = UDim.new(0, 6)
    CB_Corner.Parent = CloseBtn

    -- ============================================================
    -- BEHAVIOR
    -- ============================================================
    local verifying = false

    local function setStatus(text, color)
        Status.Text = text
        Status.TextColor3 = color or Config.TextMuted
    end

    -- Hover effects
    VerifyBtn.MouseEnter:Connect(function()
        TweenService:Create(VerifyBtn, TweenInfo.new(0.15), { BackgroundColor3 = Config.AccentHover }):Play()
    end)
    VerifyBtn.MouseLeave:Connect(function()
        TweenService:Create(VerifyBtn, TweenInfo.new(0.15), { BackgroundColor3 = Config.Accent }):Play()
    end)

    LicenceCard.MouseEnter:Connect(function()
        TweenService:Create(LC_Stroke, TweenInfo.new(0.15), { Color = Config.Accent }):Play()
        TweenService:Create(LicenceCard, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(22, 27, 38) }):Play()
    end)
    LicenceCard.MouseLeave:Connect(function()
        TweenService:Create(LC_Stroke, TweenInfo.new(0.15), { Color = Config.Border }):Play()
        TweenService:Create(LicenceCard, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(18, 22, 32) }):Play()
    end)

    -- Click licence → open website
    LicenceCard.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(Config.ApiUrl)
        end
        if request then
            pcall(function()
                request({
                    Url = Config.ApiUrl,
                    Method = "GET"
                })
            end)
        end
        setStatus("Link copied: " .. Config.ApiUrl, Config.Accent)
    end)

    -- Close
    CloseBtn.MouseButton1Click:Connect(function()
        Gui:Destroy()
    end)

    -- Minimize (hide card, keep backdrop)
    local minimized = false
    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            TweenService:Create(Card, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                Size = UDim2.fromOffset(520, 40),
                Position = UDim2.new(0.5, -260, 1, -50)
            }):Play()
            MinBtn.Text = "▲"
        else
            TweenService:Create(Card, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                Size = UDim2.fromOffset(520, 380),
                Position = UDim2.new(0.5, -260, 0.5, -190)
            }):Play()
            MinBtn.Text = "—"
        end
    end)

    -- Verify
    local function attemptVerify()
        if verifying then return end
        local key = Input.Text
        if key == "" or #key < 8 then
            setStatus("Please enter a valid key", Config.Error)
            return
        end

        verifying = true
        VerifyBtn.Text = "Verifying..."
        VerifyBtn.BackgroundColor3 = Color3.fromRGB(80, 90, 110)
        setStatus("Contacting server...", Config.TextSecond)

        local valid, reason = verifyKey(key)

        verifying = false
        VerifyBtn.Text = Config.VerifyText
        VerifyBtn.BackgroundColor3 = Config.Accent

        if valid then
            setStatus("Key accepted. Welcome!", Config.Success)

            -- Fade out animation
            TweenService:Create(Card, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(CardStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
            TweenService:Create(Backdrop, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
            for _, obj in ipairs(Card:GetDescendants()) do
                if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                    TweenService:Create(obj, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
                elseif obj:IsA("Frame") then
                    TweenService:Create(obj, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
                elseif obj:IsA("UIStroke") then
                    TweenService:Create(obj, TweenInfo.new(0.35), { Transparency = 1 }):Play()
                end
            end

            task.wait(0.45)
            Gui:Destroy()

            pcall(function()
                if writefile and isfolder then
                    writefile(Config.StorageKey .. ".txt", key)
                end
            end)

            if onSuccess then onSuccess() end
        else
            local msg = "Invalid key"
            if reason == "expired" then msg = "Key expired"
            elseif reason == "hwid_mismatch" then msg = "Key bound to another device"
            elseif reason == "revoked" then msg = "Key revoked"
            elseif reason == "not_found" then msg = "Key not found"
            elseif reason == "rate_limited" then msg = "Too many attempts, try again later"
            elseif reason == "network_error" then msg = "Network error"
            elseif reason == "server_error" then msg = "Server error"
            elseif reason == "invalid_format" then msg = "Invalid key format"
            elseif reason == "invalid_hwid" then msg = "Invalid hardware id"
            end
            setStatus(msg, Config.Error)

            TweenService:Create(IB_Stroke, TweenInfo.new(0.15), { Color = Config.Error }):Play()
            task.wait(0.7)
            TweenService:Create(IB_Stroke, TweenInfo.new(0.15), { Color = Config.Border }):Play()
        end
    end

    VerifyBtn.MouseButton1Click:Connect(attemptVerify)
    Input.FocusLost:Connect(function(enter)
        if enter then attemptVerify() end
    end)

    -- Auto-focus input
    task.wait(0.1)
    Input:CaptureFocus()

    return Gui
end

return GetkeyUI
