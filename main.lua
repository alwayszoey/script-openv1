-- ============================================================
-- UNIVERSAL HUB - v1.0.0
-- Getkey UI + MacLib + Full Features
-- ============================================================

--// Services
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

--// Config
local Config = {
    Title = "UNIVERSAL HUB",
    Subtitle = "v1.0.0 • Verified Access",
    Version = "v1.0.0",
    ApiUrl = "https://getkeyxcl.vercel.app",
    StorageKey = "universalhub_key_v1",
    MacLibUrl = "https://raw.githubusercontent.com/alwayszoey/script-openv1/refs/heads/main/maclib.lua",
    GetkeyUiUrl = "https://raw.githubusercontent.com/alwayszoey/script-openv1/refs/heads/main/getkey-ui.lua"
}

--// State
local State = {
    BypassEnabled=false, BypassRange=500, RemoveCollision=false, AutoEnterLocked=false,
    SpeedEnabled=false, SpeedValue=16, MaxSpeed=250,
    FlyEnabled=false, FlySpeed=60,
    NoclipEnabled=false, InfJumpEnabled=false, AntiFlingEnabled=false, AntiVoidEnabled=false,
    AntiBanEnabled=true, JitterEnabled=true, RateLimitEnabled=true, LegitMode=false, RampUpEnabled=true,
    ShowCoords=true, AntiAfkEnabled=true, SavedPositions={},
}

local AntiBan = { tickCounter = 0, currentRampSpeed = 16 }

--// Cleanup old GUIs
for _, name in ipairs({"UniversalHub", "UniversalHubLoading", "GetkeyUI", "UniversalHubToggle", "UniversalHubHUD"}) do
    pcall(function()
        local o = CoreGui:FindFirstChild(name)
        if o then o:Destroy() end
    end)
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg and pg:FindFirstChild(name) then pg[name]:Destroy() end
    end)
end

--// HWID
local function getHWID()
    local ok, id = pcall(function()
        return RbxAnalytics:GetClientId()
    end)
    if ok and id then return id end
    return "fallback-" .. tostring(LocalPlayer.UserId)
end

local HWID = getHWID()

--// Verify API
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

--// Loading Screen
local function showLoadingScreen()
    local LoadingGui = Instance.new("ScreenGui")
    LoadingGui.Name = "UniversalHubLoading"
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
    local LFS = Instance.new("UIStroke") LFS.Color = Color3.fromRGB(88, 132, 255) LFS.Thickness = 1.5 LFS.Parent = LF

    local LL = Instance.new("TextLabel")
    LL.Size = UDim2.new(1, 0, 0, 40); LL.Position = UDim2.new(0, 0, 0, 20)
    LL.BackgroundTransparency = 1; LL.Text = Config.Title
    LL.TextColor3 = Color3.fromRGB(88, 132, 255); LL.TextSize = 24; LL.Font = Enum.Font.GothamBlack; LL.Parent = LF

    local LV = Instance.new("TextLabel")
    LV.Size = UDim2.new(1, 0, 0, 14); LV.Position = UDim2.new(0, 0, 0, 58)
    LV.BackgroundTransparency = 1; LV.Text = Config.Version
    LV.TextColor3 = Color3.fromRGB(110, 110, 125); LV.TextSize = 10; LV.Font = Enum.Font.Gotham; LV.Parent = LF

    local LBB = Instance.new("Frame")
    LBB.Size = UDim2.new(0, 260, 0, 6); LBB.Position = UDim2.new(0.5, -130, 0, 100)
    LBB.BackgroundColor3 = Color3.fromRGB(45, 45, 55); LBB.BorderSizePixel = 0; LBB.Parent = LF
    local LBBC = Instance.new("UICorner") LBBC.CornerRadius = UDim.new(1, 0) LBBC.Parent = LBB

    local LBF = Instance.new("Frame")
    LBF.Size = UDim2.new(0, 0, 1, 0); LBF.BackgroundColor3 = Color3.fromRGB(88, 132, 255)
    LBF.BorderSizePixel = 0; LBF.Parent = LBB
    local LBFC = Instance.new("UICorner") LBFC.CornerRadius = UDim.new(1, 0) LBFC.Parent = LBB

    local LS = Instance.new("TextLabel")
    LS.Size = UDim2.new(1, 0, 0, 14); LS.Position = UDim2.new(0, 0, 0, 120)
    LS.BackgroundTransparency = 1; LS.Text = "Loading..."
    LS.TextColor3 = Color3.fromRGB(160, 160, 175); LS.TextSize = 10; LS.Font = Enum.Font.GothamBold; LS.Parent = LF

    local steps = {"Loading modules...", "Checking updates...", "Preparing UI...", "Ready!"}
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
end

--// MacLib Hub
local function buildMainUI()
    local MacLib = loadstring(game:HttpGet(Config.MacLibUrl))()

    local Window = MacLib:Window({
        Title = Config.Title,
        Subtitle = Config.Subtitle,
        Size = UDim2.fromOffset(620, 420),
        DragStyle = 1,
        ShowUserInfo = true,
        Keybind = Enum.KeyCode.RightControl,
        AcrylicBlur = false
    })

    MacLib:SetFolder("UniversalHub")

    -- Global settings
    Window:GlobalSetting({
        Name = "UI Blur",
        Default = false,
        Callback = function(bool)
            Window:SetAcrylicBlurState(bool)
        end
    })

    Window:GlobalSetting({
        Name = "Notifications",
        Default = true,
        Callback = function(bool)
            Window:SetNotificationsState(bool)
        end
    })

    Window:GlobalSetting({
        Name = "Show User Info",
        Default = true,
        Callback = function(bool)
            Window:SetUserInfoState(bool)
        end
    })

    Window:GlobalSetting({
        Name = "Coordinate HUD",
        Default = true,
        Callback = function(bool)
            State.ShowCoords = bool
        end
    })

    -- Tab group
    local tabGroup = Window:TabGroup()

    local tabs = {
        Bypass   = tabGroup:Tab({ Name = "Bypass",   Image = "rbxassetid://18821914323" }),
        Movement = tabGroup:Tab({ Name = "Movement", Image = "rbxassetid://10734950309" }),
        SaveTP   = tabGroup:Tab({ Name = "Save/TP",  Image = "rbxassetid://10709791437" }),
        AntiBan  = tabGroup:Tab({ Name = "Anti-Ban", Image = "rbxassetid://18772190202" }),
        Settings = tabGroup:Tab({ Name = "Settings", Image = "rbxassetid://108952102602834" }),
    }

    --// Bypass functions
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

    --// TAB: BYPASS
    local bypassSection = tabs.Bypass:Section({ Side = "Left" })
    bypassSection:Header({ Text = "Bypass Gate System" })

    bypassSection:Toggle({
        Name = "Bypass All Gates",
        Default = false,
        Callback = function(v)
            State.BypassEnabled = v
            if v then bypassAllGates() end
        end
    })

    bypassSection:Slider({
        Name = "Bypass Range",
        Default = 500, Minimum = 50, Maximum = 1000,
        Suffix = " studs",
        Callback = function(v) State.BypassRange = v end
    })

    bypassSection:Toggle({
        Name = "Remove All Collision",
        Default = false,
        Callback = function(v)
            State.RemoveCollision = v
            if v then disableAllCollision() else restoreAllCollision() end
        end
    })

    bypassSection:Toggle({
        Name = "Auto Enter Locked Zones",
        Default = false,
        Callback = function(v) State.AutoEnterLocked = v end
    })

    bypassSection:Divider()
    bypassSection:Header({ Text = "Quick Actions" })

    bypassSection:Button({
        Name = "Bypass All Now",
        Callback = function()
            local a = bypassAllGates()
            local c = bypassAllPrompts()
            Window:Notify({
                Title = Config.Title,
                Description = "Bypassed " .. a .. " gates, " .. c .. " prompts",
                Lifetime = 3
            })
        end
    })

    bypassSection:Button({
        Name = "Activate All Prompts",
        Callback = function()
            local c = activateAllPrompts()
            Window:Notify({ Title = Config.Title, Description = "Activated " .. c .. " prompts", Lifetime = 3 })
        end
    })

    bypassSection:Button({
        Name = "Teleport Through Gate",
        Callback = function() teleportThroughGate() end
    })

    bypassSection:Button({
        Name = "Restore All Gates",
        Callback = function()
            for obj in pairs(bypassedGates) do
                if obj and obj.Parent then
                    pcall(function()
                        obj.CanCollide = true; obj.CanTouch = true; obj.CanQuery = true; obj.Transparency = 0
                    end)
                end
            end
            bypassedGates = {}; restoreAllCollision()
        end
    })

    --// TAB: MOVEMENT
    local movementSection = tabs.Movement:Section({ Side = "Left" })
    movementSection:Header({ Text = "Speed" })

    movementSection:Toggle({
        Name = "Speed Hack",
        Default = false,
        Callback = function(v) State.SpeedEnabled = v end
    })

    movementSection:Slider({
        Name = "Speed Value",
        Default = 16, Minimum = 16, Maximum = 500,
        Suffix = " WS",
        Callback = function(v) State.SpeedValue = v end
    })

    movementSection:Slider({
        Name = "Max Speed Cap",
        Default = 250, Minimum = 50, Maximum = 500,
        Suffix = " WS",
        Callback = function(v) State.MaxSpeed = v end
    })

    movementSection:Divider()
    movementSection:Header({ Text = "Fly" })

    movementSection:Toggle({
        Name = "Fly",
        Default = false,
        Callback = function(v) State.FlyEnabled = v end
    })

    movementSection:Slider({
        Name = "Fly Speed",
        Default = 60, Minimum = 30, Maximum = 300,
        Suffix = " studs",
        Callback = function(v) State.FlySpeed = v end
    })

    movementSection:Divider()
    movementSection:Header({ Text = "Extras" })

    movementSection:Toggle({ Name = "Noclip", Default = false, Callback = function(v) State.NoclipEnabled = v end })
    movementSection:Toggle({ Name = "Infinite Jump", Default = false, Callback = function(v) State.InfJumpEnabled = v end })
    movementSection:Toggle({ Name = "Anti-Fling", Default = false, Callback = function(v) State.AntiFlingEnabled = v end })
    movementSection:Toggle({ Name = "Anti-Void", Default = false, Callback = function(v) State.AntiVoidEnabled = v end })
    movementSection:Toggle({ Name = "Anti-AFK", Default = false, Callback = function(v) State.AntiAfkEnabled = v end })

    --// TAB: SAVE/TP
    local stpSection = tabs.SaveTP:Section({ Side = "Left" })
    stpSection:Header({ Text = "Save Position" })

    local saveName = "spot1"
    stpSection:Input({
        Name = "Save Name",
        Placeholder = "e.g. base",
        Default = "spot1",
        Callback = function(v) saveName = v end
    })

    stpSection:Button({
        Name = "Save Current Position",
        Callback = function()
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            State.SavedPositions[saveName] = {
                x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z
            }
            Window:Notify({ Title = Config.Title, Description = "Saved " .. saveName, Lifetime = 3 })
        end
    })

    stpSection:Divider()
    stpSection:Header({ Text = "Teleport to XYZ" })

    local xyzValue = "0, 50, 0"
    stpSection:Input({
        Name = "Coordinates (x, y, z)",
        Placeholder = "0, 50, 0",
        Default = "0, 50, 0",
        Callback = function(v) xyzValue = v end
    })

    stpSection:Button({
        Name = "Teleport to XYZ",
        Callback = function()
            local coords = {}
            for n in string.gmatch(xyzValue, "[^,%s]+") do table.insert(coords, tonumber(n)) end
            if #coords == 3 then
                local char = LocalPlayer.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.CFrame = CFrame.new(Vector3.new(coords[1], coords[2], coords[3]))
                    end
                end
            end
        end
    })

    stpSection:Divider()
    stpSection:Header({ Text = "Quick Actions" })

    stpSection:Button({
        Name = "Teleport to Spawn",
        Callback = function()
            local spawn = Workspace:FindFirstChildOfClass("SpawnLocation")
            if spawn then
                local char = LocalPlayer.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then hrp.CFrame = CFrame.new(spawn.Position + Vector3.new(0, 5, 0)) end
                end
            end
        end
    })

    stpSection:Button({
        Name = "Teleport Up (+50Y)",
        Callback = function()
            local char = LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = hrp.CFrame + Vector3.new(0, 50, 0) end
            end
        end
    })

    --// TAB: ANTI-BAN
    local abSection = tabs.AntiBan:Section({ Side = "Left" })
    abSection:Header({ Text = "Anti-Ban Core" })

    abSection:Toggle({ Name = "Anti-Ban System",   Default = true,  Callback = function(v) State.AntiBanEnabled = v end })
    abSection:Toggle({ Name = "Jitter ±2",         Default = true,  Callback = function(v) State.JitterEnabled = v end })
    abSection:Toggle({ Name = "Rate Limit 20Hz",   Default = true,  Callback = function(v) State.RateLimitEnabled = v end })
    abSection:Toggle({ Name = "Ramp Up Smooth",    Default = true,  Callback = function(v) State.RampUpEnabled = v end })
    abSection:Toggle({ Name = "Legit Mode (60)",   Default = false, Callback = function(v) State.LegitMode = v end })

    abSection:Divider()
    abSection:Header({ Text = "Emergency" })

    abSection:Button({
        Name = "Panic Cleanup",
        Callback = function()
            resetCharacterPhysics()
            State.SpeedEnabled = false
            State.FlyEnabled = false
            State.NoclipEnabled = false
            State.BypassEnabled = false
            State.RemoveCollision = false
            AntiBan.currentRampSpeed = 16
            Window:Notify({ Title = Config.Title, Description = "Panic cleanup done", Lifetime = 3 })
        end
    })

    abSection:Button({
        Name = "Reset Physics",
        Callback = function() resetCharacterPhysics() end
    })

    --// TAB: SETTINGS
    local setSection = tabs.Settings:Section({ Side = "Left" })
    setSection:Header({ Text = "Display" })

    setSection:Toggle({
        Name = "Coordinate HUD",
        Default = true,
        Callback = function(v) State.ShowCoords = v end
    })

    setSection:Divider()
    setSection:Header({ Text = "Script" })

    setSection:Button({
        Name = "Rejoin Server",
        Callback = function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end
    })

    setSection:Button({
        Name = "Unload Script",
        Callback = function()
            resetCharacterPhysics()
            Window:Unload()
        end
    })

    setSection:Divider()
    setSection:Header({ Text = "About" })

    setSection:Label({ Text = Config.Title .. " " .. Config.Version })
    setSection:SubLabel({ Text = "Powered by MacLib UI" })

    tabs.Bypass:Select()

    --// CORE LOOPS
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
                else
                    AntiBan.currentRampSpeed = target
                end
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
                bv.Name = "SpeedBV"
                bv.MaxForce = Vector3.new(math.huge, 0, math.huge)
                bv.Parent = hrp
            end
            if hum.MoveDirection.Magnitude > 0.1 then
                local dir = hum.MoveDirection
                bv.Velocity = Vector3.new(dir.X * sp, 0, dir.Z * sp)
            else
                bv.Velocity = Vector3.new(0, 0, 0)
            end
        else
            pcall(function() hum.WalkSpeed = 16 end)
            pcall(function() hrp.Velocity = Vector3.new(0, hrp.Velocity.Y, 0) end)
            local bv = hrp:FindFirstChild("SpeedBV")
            if bv then bv:Destroy() end
        end
    end)

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
                    pcall(function()
                        hrp.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 1, 1)
                    end)
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

    --// Fly
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
        bv.Name = "FlyBV"
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.Parent = hrp

        local bg = Instance.new("BodyGyro")
        bg.Name = "FlyBG"
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.P = 10000
        bg.D = 500
        bg.Parent = hrp

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

    --// COORDINATE HUD
    local CoordGui = Instance.new("ScreenGui")
    CoordGui.Name = "UniversalHubHUD"
    CoordGui.ResetOnSpawn = false
    CoordGui.IgnoreGuiInset = true
    pcall(function() CoordGui.Parent = CoreGui end)
    if not CoordGui.Parent then CoordGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local CoordHUD = Instance.new("Frame")
    CoordHUD.Size = UDim2.new(0, 190, 0, 62)
    CoordHUD.Position = UDim2.new(1, -200, 0, 60)
    CoordHUD.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    CoordHUD.BackgroundTransparency = 0.2
    CoordHUD.BorderSizePixel = 0
    CoordHUD.Active = true
    CoordHUD.Draggable = true
    CoordHUD.Parent = CoordGui
    local CHC = Instance.new("UICorner") CHC.CornerRadius = UDim.new(0, 8) CHC.Parent = CoordHUD
    local CHS = Instance.new("UIStroke") CHS.Color = Color3.fromRGB(88, 132, 255) CHS.Thickness = 1 CHS.Transparency = 0.5 CHS.Parent = CoordHUD

    local CoordTitle = Instance.new("TextLabel")
    CoordTitle.Size = UDim2.new(1, -12, 0, 14)
    CoordTitle.Position = UDim2.new(0, 6, 0, 4)
    CoordTitle.BackgroundTransparency = 1
    CoordTitle.Text = "POSITION"
    CoordTitle.TextColor3 = Color3.fromRGB(88, 132, 255)
    CoordTitle.TextSize = 9
    CoordTitle.Font = Enum.Font.GothamBold
    CoordTitle.TextXAlignment = Enum.TextXAlignment.Left
    CoordTitle.Parent = CoordHUD

    local CoordText = Instance.new("TextLabel")
    CoordText.Size = UDim2.new(1, -12, 0, 18)
    CoordText.Position = UDim2.new(0, 6, 0, 18)
    CoordText.BackgroundTransparency = 1
    CoordText.Text = "X: 0.0   Y: 0.0\nZ: 0.0"
    CoordText.TextColor3 = Color3.fromRGB(245, 245, 250)
    CoordText.TextSize = 10
    CoordText.Font = Enum.Font.Code
    CoordText.TextXAlignment = Enum.TextXAlignment.Left
    CoordText.TextYAlignment = Enum.TextYAlignment.Top
    CoordText.Parent = CoordHUD

    local StatsText = Instance.new("TextLabel")
    StatsText.Size = UDim2.new(1, -12, 0, 12)
    StatsText.Position = UDim2.new(0, 6, 0, 44)
    StatsText.BackgroundTransparency = 1
    StatsText.Text = "FPS: --"
    StatsText.TextColor3 = Color3.fromRGB(160, 160, 175)
    StatsText.TextSize = 9
    StatsText.Font = Enum.Font.Code
    StatsText.TextXAlignment = Enum.TextXAlignment.Left
    StatsText.Parent = CoordHUD

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

    --// Notification
    Window:Notify({
        Title = Config.Title,
        Description = "Loaded! Press Right Ctrl to toggle the menu.",
        Lifetime = 6
    })

    print("[" .. Config.Title .. "] " .. Config.Version .. " loaded")
    print("[" .. Config.Title .. "] Right Ctrl = toggle UI")
end

--// Entry Point
local function tryStoredKey()
    if not (readfile and isfile) then return nil end
    local ok, content = pcall(function()
        return readfile(Config.StorageKey .. ".txt")
    end)
    if ok and content and #content > 8 then
        return content
    end
    return nil
end

local function startFlow()
    showLoadingScreen()

    -- 1) ลองคีย์ที่บันทึกไว้ก่อน
    local stored = tryStoredKey()
    if stored then
        local valid = verifyKey(stored)
        if valid then
            buildMainUI()
            return
        end
    end

    -- 2) เปิดหน้า Getkey UI
    local GetkeyUI = loadstring(game:HttpGet(Config.GetkeyUiUrl))()

    GetkeyUI.Show(function()
        -- onSuccess: เปิด Hub
        buildMainUI()
    end)
end

startFlow()
