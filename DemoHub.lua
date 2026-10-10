
-- AxionLib Demo Hub
-- Roblox Luau / Executor environment

local LibraryURL =
    "https://raw.githubusercontent.com/alwayszoey/script-openv1/refs/heads/main/Lib/AxionLib.lua"

local ok, AxionLib = pcall(function()
    return loadstring(game:HttpGet(LibraryURL))()
end)

if not ok or type(AxionLib) ~= "table" then
    warn("[AxionDemo] Failed to load AxionLib:", AxionLib)
    return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

-- Create the window using the library
local Hub = AxionLib:CreateWindow({
    Name = "Axion Demo",
    Subtitle = "Player Inspector",
    Version = "v1.0",
    Loading = true,
    AutoReady = true,
    ToggleKey = "RightShift",

    ConfigFolder = "AxionDemo",

    Theme = {
        accentBlue = Color3.fromRGB(84, 38, 232),
        accentPink = Color3.fromRGB(172, 44, 248),
    },
})

if not Hub then
    warn("[AxionDemo] Window creation failed")
    return
end

-- Dashboard tab
local Dashboard = Hub:AddTab({
    Name = "Dashboard",
    Description = "Overview and status",
    Icon = "layout-dashboard",
})

Dashboard:AddSection({
    Name = "Welcome",
})

Dashboard:AddParagraph({
    Title = "AxionLib is running",
    Text = "This demo uses the original AxionLib window, tabs, theme and notifications.",
})

Dashboard:AddButton({
    Name = "Test Notification",
    Description = "Send a demo notification",
    Callback = function()
        Hub:Notify("AxionLib is working!", "good")
    end,
})

Dashboard:AddButton({
    Name = "Show Player Info",
    Description = "Display your current character status",
    Callback = function()
        local Character = LocalPlayer.Character
        local Humanoid = Character
            and Character:FindFirstChildOfClass("Humanoid")

        if not Humanoid then
            Hub:Notify("Character not found", "bad")
            return
        end

        Hub:Notify(
            string.format(
                "Health: %d | Speed: %d",
                math.floor(Humanoid.Health),
                math.floor(Humanoid.WalkSpeed)
            ),
            "good"
        )
    end,
})

-- Player tab
local PlayerTab = Hub:AddTab({
    Name = "Player",
    Description = "Character test controls",
    Icon = "users",
})

PlayerTab:AddSection({
    Name = "Movement",
})

PlayerTab:AddSlider({
    Name = "WalkSpeed",
    Description = "Local character movement test",
    Min = 8,
    Max = 32,
    Default = 16,
    Increment = 1,
    Callback = function(Value)
        local Character = LocalPlayer.Character
        local Humanoid = Character
            and Character:FindFirstChildOfClass("Humanoid")

        if Humanoid then
            Humanoid.WalkSpeed = Value
        end
    end,
})

PlayerTab:AddButton({
    Name = "Reset WalkSpeed",
    Description = "Restore the default speed",
    Callback = function()
        local Character = LocalPlayer.Character
        local Humanoid = Character
            and Character:FindFirstChildOfClass("Humanoid")

        if Humanoid then
            Humanoid.WalkSpeed = 16
            Hub:Notify("WalkSpeed reset to 16", "good")
        end
    end,
})

-- Settings tab
local Settings = Hub:AddTab({
    Name = "Settings",
    Description = "Demo preferences",
    Icon = "settings",
})

Settings:AddSection({
    Name = "Interface",
})

Settings:AddButton({
    Name = "Test UI Sound",
    Description = "Play a built-in library sound",
    Callback = function()
        AxionLib:PlaySound("Click")
        Hub:Notify("UI sound requested", "muted")
    end,
})

Settings:AddButton({
    Name = "Minimize / Restore",
    Description = "Toggle the AxionLib window",
    Callback = function()
        Hub:Toggle()
    end,
})

Settings:AddButton({
    Name = "Close Demo",
    Description = "Destroy the window and its connections",
    Callback = function()
        Hub:Destroy()
    end,
})

Hub:Notify("Axion Demo loaded successfully", "good")
