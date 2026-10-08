--[[
    AxionHub :: MapDumper v2
    Full recon pipeline for auto-farm script development.
    Stages: Map / Remotes / Modules / Constants
    UI: purple-black gradient (AxionHub theme)
--]]

local HttpService   = game:GetService("HttpService")
local Players       = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

--=====================================================================
-- THEME
--=====================================================================
local Theme = {
    BgTop     = Color3.fromRGB(28, 12, 48),
    BgMid     = Color3.fromRGB(20, 8, 38),
    BgBottom  = Color3.fromRGB(10, 6, 18),
    Accent    = Color3.fromRGB(155, 60, 235),
    Accent2   = Color3.fromRGB(90, 20, 150),
    Text      = Color3.fromRGB(235, 225, 255),
    SubText   = Color3.fromRGB(170, 150, 200),
    Border    = Color3.fromRGB(120, 40, 200),
    Button    = Color3.fromRGB(60, 20, 110),
    ButtonHov = Color3.fromRGB(110, 40, 190),
    Good      = Color3.fromRGB(150, 255, 180),
    Bad       = Color3.fromRGB(255, 90, 90),
}

local function applyGradient(frame, rot)
    local g = Instance.new("UIGradient")
    g.Rotation = rot or 90
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Theme.BgTop),
        ColorSequenceKeypoint.new(0.5, Theme.BgMid),
        ColorSequenceKeypoint.new(1,   Theme.BgBottom),
    })
    g.Parent = frame
end

local function applyAccentGradient(frame)
    local g = Instance.new("UIGradient")
    g.Rotation = 0
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Accent),
        ColorSequenceKeypoint.new(1, Theme.Accent2),
    })
    g.Parent = frame
end

--=====================================================================
-- STAGE 1 : MAP DUMPER  (structural snapshot)
--=====================================================================
local function describeInstance(inst, depth)
    depth = depth or 0
    if depth > 10 then return { _truncated = true } end

    local data = { ClassName = inst.ClassName, Name = inst.Name }

    if inst:IsA("BasePart") then
        data.Position = { inst.Position.X, inst.Position.Y, inst.Position.Z }
        data.Size     = { inst.Size.X, inst.Size.Y, inst.Size.Z }
        data.Anchored = inst.Anchored
        data.CanCollide = inst.CanCollide
        data.Transparency = inst.Transparency
        data.Material = tostring(inst.Material)
    end

    if inst:IsA("Humanoid") then
        data.Health = inst.Health
        data.MaxHealth = inst.MaxHealth
        data.WalkSpeed = inst.WalkSpeed
    end

    if inst:IsA("Model") then
        data.PrimaryPart = inst.PrimaryPart and inst.PrimaryPart.Name or nil
    end

    -- Attributes (typed)
    local attrs = inst:GetAttributes()
    if next(attrs) then
        data.Attributes = {}
        for k, v in pairs(attrs) do
            local t = typeof(v)
            if t == "Vector3" then data.Attributes[k] = { v.X, v.Y, v.Z }
            elseif t == "CFrame" then data.Attributes[k] = { v:GetComponents() }
            elseif t == "Color3" then data.Attributes[k] = { v.R, v.G, v.B }
            elseif t == "Instance" then data.Attributes[k] = v:GetFullName()
            elseif t == "table" or t == "number" or t == "string" or t == "boolean" then
                data.Attributes[k] = v
            else data.Attributes[k] = tostring(v) end
        end
    end

    local ok, tags = pcall(function() return inst:GetTags() end)
    if ok and #tags > 0 then data.Tags = tags end

    local kids = inst:GetChildren()
    if #kids > 0 then
        data.Children = {}
        for _, c in ipairs(kids) do
            table.insert(data.Children, describeInstance(c, depth + 1))
        end
    end
    return data
end

local function findRemotes(root)
    local remotes = {}
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction")
        or d:IsA("UnreliableRemoteEvent") then
            table.insert(remotes, {
                ClassName = d.ClassName,
                Path      = d:GetFullName(),
            })
        end
    end
    return remotes
end

local Stage = {}

Stage.Map = function()
    local wsOut = {}
    for _, c in ipairs(workspace:GetChildren()) do
        if c ~= Players.LocalPlayer and not c:IsDescendantOf(Players.LocalPlayer) then
            table.insert(wsOut, describeInstance(c))
        end
    end
    local rsOut = {}
    for _, c in ipairs(ReplicatedStorage:GetChildren()) do
        table.insert(rsOut, describeInstance(c))
    end
    local plrOut = {}
    for _, p in ipairs(Players:GetPlayers()) do
        table.insert(plrOut, {
            Name = p.Name, UserId = p.UserId,
            Team = p.Team and p.Team.Name or nil,
            Character = p.Character and describeInstance(p.Character) or nil,
            Backpack = (function()
                local bp = p:FindFirstChildOfClass("Backpack")
                return bp and describeInstance(bp) or nil
            end)(),
        })
    end

    return {
        Source = "Map",
        PlaceId = game.PlaceId,
        JobId = game.JobId,
        MapName = (function()
            local ok, info = pcall(function()
                return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
            end)
            return (ok and info and info.Name) or tostring(game.PlaceId)
        end)(),
        Remotes = findRemotes(game),
        Workspace = wsOut,
        ReplicatedStorage = rsOut,
        Players = plrOut,
    }
end

--=====================================================================
-- STAGE 2 : REMOTE LOGGER  (what args does each remote take?)
--=====================================================================
local RemoteLog = { events = {}, active = false, conn = nil, count = 0 }

Stage.RemotesStart = function()
    if RemoteLog.active then return RemoteLog end
    RemoteLog.active = true
    RemoteLog.count = 0

    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if RemoteLog.active
        and (method == "FireServer" or method == "InvokeServer")
        and typeof(self) == "Instance"
        and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")
             or self:IsA("UnreliableRemoteEvent")) then

            local args = { ... }
            local serial = {}
            for i, a in ipairs(args) do
                local t = typeof(a)
                if t == "Instance" then serial[i] = { _type = "Instance", Path = a:GetFullName() }
                elseif t == "Vector3" then serial[i] = { _type = "Vector3", X = a.X, Y = a.Y, Z = a.Z }
                elseif t == "CFrame" then serial[i] = { _type = "CFrame", C = { a:GetComponents() } }
                elseif t == "table" then
                    local ok, enc = pcall(function() return HttpService:JSONEncode(a) end)
                    serial[i] = { _type = "table", JSON = ok and enc or tostring(a) }
                elseif t == "number" or t == "string" or t == "boolean" then
                    serial[i] = { _type = t, Value = a }
                else
                    serial[i] = { _type = t, Value = tostring(a) }
                end
            end

            RemoteLog.count = RemoteLog.count + 1
            table.insert(RemoteLog.events, {
                Time     = os.time(),
                Method   = method,
                Remote   = self:GetFullName(),
                ArgCount = #args,
                Args     = serial,
            })
        end
        return oldNamecall(self, ...)
    end)

    setreadonly(mt, true)
    return RemoteLog
end

Stage.RemotesStop = function()
    RemoteLog.active = false
    return RemoteLog
end

--=====================================================================
-- STAGE 3 : MODULE SOURCE EXTRACTOR  (bytecode for decompiler)
--=====================================================================
Stage.Modules = function()
    local modules = {}
    local ok, bytecodeFn = pcall(function() return getscriptbytecode end)
    local ok2, getScript = pcall(function() return getscriptclosure end)

    for _, d in ipairs(game:GetDescendants()) do
        if d:IsA("ModuleScript") or d:IsA("Script") or d:IsA("LocalScript") then
            local entry = {
                ClassName = d.ClassName,
                Path      = d:GetFullName(),
                Source    = "[not readable client-side]",
                Bytecode  = nil,
            }
            if ok and d:IsA("ModuleScript") then
                local bOk, bc = pcall(bytecodeFn, d)
                if bOk and bc then
                    entry.Bytecode = base64 and base64.encode(bc) or "[bytecode captured, no base64 lib]"
                    entry.BytecodeLength = #bc
                end
            end
            table.insert(modules, entry)
        end
    end
    return modules
end

--=====================================================================
-- STAGE 4 : CONSTANT DUMP  (strings/numbers inside a module)
--=====================================================================
Stage.Constants = function(modulePath)
    local target
    if modulePath then
        target = game:FindFirstChild(modulePath, true)
    end

    local results = {}
    local targets = {}
    if target then
        table.insert(targets, target)
    else
        for _, d in ipairs(game:GetDescendants()) do
            if d:IsA("ModuleScript") then table.insert(targets, d) end
        end
    end

    for _, d in ipairs(targets) do
        local entry = { Path = d:GetFullName(), Constants = {}, Protos = 0 }
        local ok, closure = pcall(getscriptclosure, d)
        if ok and closure then
            local seen, consts = {}, {}
            local function walk(fn)
                local cOk, k = pcall(debug.getconstants, fn)
                if cOk then
                    for _, v in ipairs(k) do
                        local t = type(v)
                        if t == "string" and #v > 1 and not seen[v] then
                            seen[v] = true
                            table.insert(consts, v)
                        end
                    end
                end
                local pOk, protos = pcall(debug.getprotos, fn)
                if pOk then
                    for _, p in ipairs(protos) do
                        entry.Protos = entry.Protos + 1
                        walk(p)
                    end
                end
            end
            local wOk, err = pcall(walk, closure)
            if not wOk then entry.Error = tostring(err) end
            entry.Constants = consts
        else
            entry.Error = "getscriptclosure failed"
        end
        table.insert(results, entry)
    end
    return results
end

--=====================================================================
-- SAVE
--=====================================================================
local function sanitize(name)
    return (name:gsub("[^%w%-_%. ]", "_"))
end

local function saveJSON(sourceName, data, customName)
    local fileName
    if customName and customName ~= "" then
        fileName = sanitize(customName) .. ".json"
    else
        local mapName = "Map"
        pcall(function()
            mapName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
        end)
        fileName = sanitize(mapName) .. "_" .. sourceName .. ".json"
    end

    local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
    if not ok then return false, "JSON encode failed: " .. tostring(encoded) end

    local wOk, err = pcall(writefile, fileName, encoded)
    if wOk then return true, fileName, #encoded end
    return false, "writefile failed: " .. tostring(err)
end

--=====================================================================
-- UI
--=====================================================================
local function buildUI()
    local existing = game:GetService("CoreGui"):FindFirstChild("AxionHub_MapDumper")
    if existing then existing:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "AxionHub_MapDumper"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = game:GetService("CoreGui")

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 440, 0, 470)
    main.Position = UDim2.new(0.5, -220, 0.5, -235)
    main.BackgroundColor3 = Theme.BgBottom
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = gui
    applyGradient(main)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Border
    stroke.Thickness = 2
    stroke.Transparency = 0.2
    stroke.Parent = main

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = main

    -- HEADER
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundColor3 = Theme.Accent2
    header.BorderSizePixel = 0
    header.Parent = main
    applyAccentGradient(header)

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
    title.Text = "AxionHub  •  MapDumper v2"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Theme.Text
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 14, 0, 0)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local close = Instance.new("TextButton")
    close.Text = "✕"
    close.Font = Enum.Font.GothamBold
    close.TextSize = 16
    close.TextColor3 = Theme.Text
    close.BackgroundTransparency = 1
    close.Size = UDim2.new(0, 36, 0, 36)
    close.Position = UDim2.new(1, -42, 0, 6)
    close.Parent = header
    close.MouseButton1Click:Connect(function() gui:Destroy() end)

    -- NAME BOX
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Text = "FILE NAME  (optional)"
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 11
    nameLabel.TextColor3 = Theme.SubText
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, -40, 0, 16)
    nameLabel.Position = UDim2.new(0, 20, 0, 62)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = main

    local nameBox = Instance.new("TextBox")
    nameBox.PlaceholderText = "auto: <map name>_<stage>"
    nameBox.Font = Enum.Font.Gotham
    nameBox.TextSize = 13
    nameBox.TextColor3 = Theme.Text
    nameBox.PlaceholderColor3 = Theme.SubText
    nameBox.BackgroundColor3 = Color3.fromRGB(20, 10, 35)
    nameBox.BorderSizePixel = 0
    nameBox.Size = UDim2.new(1, -40, 0, 34)
    nameBox.Position = UDim2.new(0, 20, 0, 82)
    nameBox.TextXAlignment = Enum.TextXAlignment.Left
    nameBox.ClearTextOnFocus = false
    nameBox.Parent = main

    local nCorner = Instance.new("UICorner"); nCorner.CornerRadius = UDim.new(0, 6); nCorner.Parent = nameBox
    local nStroke = Instance.new("UIStroke"); nStroke.Color = Theme.Border; nStroke.Thickness = 1; nStroke.Transparency = 0.5; nStroke.Parent = nameBox
    local nPad = Instance.new("UIPadding"); nPad.PaddingLeft = UDim.new(0, 10); nPad.PaddingRight = UDim.new(0, 10); nPad.Parent = nameBox

    -- OPTIONS
    local optLabel = Instance.new("TextLabel")
    optLabel.Text = "RECON STAGES"
    optLabel.Font = Enum.Font.GothamBold
    optLabel.TextSize = 11
    optLabel.TextColor3 = Theme.SubText
    optLabel.BackgroundTransparency = 1
    optLabel.Size = UDim2.new(1, -40, 0, 16)
    optLabel.Position = UDim2.new(0, 20, 0, 132)
    optLabel.TextXAlignment = Enum.TextXAlignment.Left
    optLabel.Parent = main

    local options = {
        { label = "1.  Dump Map  (structure + remotes)",       fn = function() return "Map", Stage.Map() end },
        { label = "2.  Start Remote Logger",                    fn = function() Stage.RemotesStart(); return "Logger", { started = true } end },
        { label = "2b. Stop + Save Remote Log",                 fn = function() return "RemoteLog", Stage.RemotesStop() end },
        { label = "3.  Extract Module Bytecode",                fn = function() return "Modules", Stage.Modules() end },
        { label = "4.  Dump Constants (all modules)",           fn = function() return "Constants", Stage.Constants() end },
    }

    local yStart, rowH = 154, 40

    for i, opt in ipairs(options) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -40, 0, 34)
        btn.Position = UDim2.new(0, 20, 0, yStart + (i - 1) * rowH)
        btn.BackgroundColor3 = Theme.Button
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Text = ""
        btn.Parent = main

        local bCorner = Instance.new("UICorner"); bCorner.CornerRadius = UDim.new(0, 6); bCorner.Parent = btn
        local bStroke = Instance.new("UIStroke"); bStroke.Color = Theme.Border; bStroke.Thickness = 1; bStroke.Transparency = 0.5; bStroke.Parent = btn

        local marker = Instance.new("Frame")
        marker.Size = UDim2.new(0, 4, 0, 22)
        marker.Position = UDim2.new(0, 0, 0.5, -11)
        marker.BackgroundColor3 = Theme.Accent
        marker.BorderSizePixel = 0
        marker.Parent = btn
        local mCorner = Instance.new("UICorner"); mCorner.CornerRadius = UDim.new(0, 2); mCorner.Parent = marker

        local txt = Instance.new("TextLabel")
        txt.Text = opt.label
        txt.Font = Enum.Font.GothamMedium
        txt.TextSize = 13
        txt.TextColor3 = Theme.Text
        txt.BackgroundTransparency = 1
        txt.Size = UDim2.new(1, -20, 1, 0)
        txt.Position = UDim2.new(0, 16, 0, 0)
        txt.TextXAlignment = Enum.TextXAlignment.Left
        txt.Parent = btn

        btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Theme.ButtonHov end)
        btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Theme.Button end)

        btn.MouseButton1Click:Connect(function()
            txt.Text = "Running..."
            txt.TextColor3 = Theme.SubText
            task.spawn(function()
                local ok, stageName, result = pcall(function()
                    local n, r = opt.fn()
                    return n, r
                end)
                if not ok then
                    txt.Text = "✕ Error: " .. tostring(stageName)
                    txt.TextColor3 = Theme.Bad
                    return
                end

                -- Logger start/stop don't save
                if stageName == "Logger" then
                    txt.Text = "✓ Logger running — go trigger remotes"
                    txt.TextColor3 = Theme.Good
                    return
                end

                local saved, pathOrErr, size = saveJSON(stageName, result, nameBox.Text)
                if saved then
                    txt.Text = "✓ " .. pathOrErr .. "  (" .. tostring(size) .. " B)"
                    txt.TextColor3 = Theme.Good
                else
                    txt.Text = "✕ " .. tostring(pathOrErr)
                    txt.TextColor3 = Theme.Bad
                end
                task.wait(3)
                txt.Text = opt.label
                txt.TextColor3 = Theme.Text
            end)
        end)
    end

    local footer = Instance.new("TextLabel")
    footer.Text = "dump map → log remotes → grab modules → read constants → write farm"
    footer.Font = Enum.Font.Gotham
    footer.TextSize = 10
    footer.TextColor3 = Theme.SubText
    footer.BackgroundTransparency = 1
    footer.Size = UDim2.new(1, -40, 0, 18)
    footer.Position = UDim2.new(0, 20, 1, -26)
    footer.TextXAlignment = Enum.TextXAlignment.Left
    footer.Parent = main
end

buildUI()
