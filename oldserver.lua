
--[[
    Axion Old Server Hop
    Universal Roblox public-server hopper
    Age options: 1 / 3 / 7 / 14 days
    Age verification depends on API-provided timestamps.
    Fallback: least-populated available public server.

    Requires an executor supporting loadstring + HTTP requests.
]]

local LIB_URL =
    "https://raw.githubusercontent.com/alwayszoey/script-openv1/refs/heads/main/Lib/AxionLib.lua"

local ICONS_URL =
    "https://raw.githubusercontent.com/alwayszoey/script-openv1/refs/heads/main/assets/dist/Icons.lua"

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local ENV = (type(getgenv) == "function" and getgenv()) or _G

ENV.AxionOldServerAge = ENV.AxionOldServerAge or 7

local VALID_AGES = {
    [1] = true,
    [3] = true,
    [7] = true,
    [14] = true,
}

local function httpGet(url)
    if type(request) == "function" then
        local response = request({
            Url = url,
            Method = "GET",
        })

        if response and response.Success and response.Body then
            return response.Body
        end

        error("HTTP request failed: " .. url)
    end

    if type(http_request) == "function" then
        local response = http_request({
            Url = url,
            Method = "GET",
        })

        if response and response.Body then
            return response.Body
        end

        error("HTTP request failed: " .. url)
    end

    return game:HttpGet(url)
end

local function makeRequest(url)
    local body = httpGet(url)
    return HttpService:JSONDecode(body)
end

-- Load the requested icon source explicitly.
local iconSource
local iconTable

local iconsOK, iconsResult = pcall(function()
    iconSource = httpGet(ICONS_URL)

    local iconChunk = loadstring(iconSource)
    assert(iconChunk, "Icons.lua could not be compiled")

    return iconChunk()
end)

if iconsOK and type(iconsResult) == "table" then
    iconTable = iconsResult
    ENV.AxionOldServerIcons = iconTable
else
    warn("[Axion Old Server Hop] Icons source could not be loaded:", iconsResult)
end

-- Download AxionLib and replace its default random Server Hop
-- with the server-selection routine below.
local function buildPatchedLibrary(source)
    local startToken = "local function serverHop()"
    local endToken = "local function rejoinServer()"

    local startAt = source:find(startToken, 1, true)
    assert(startAt, "Could not find serverHop() in AxionLib")

    local endAt = source:find(endToken, startAt + #startToken, true)
    assert(endAt, "Could not find rejoinServer() in AxionLib")

    local replacement = [=[
local function serverHop()
    if State.hopping then
        return
    end

    State.hopping = true
    notify("Searching public servers...", Config.muted)

    task.spawn(function()
        local candidates = {}
        local cursor = nil
        local pagesChecked = 0
        local MAX_PAGES = 10
        local selectedAge = tonumber(
            (type(getgenv) == "function" and getgenv() or _G).AxionOldServerAge
        ) or 7

        if selectedAge ~= 1 and selectedAge ~= 3
            and selectedAge ~= 7 and selectedAge ~= 14 then
            selectedAge = 7
        end

        local cutoff = os.time() - selectedAge * 24 * 60 * 60

        for page = 1, MAX_PAGES do
            pagesChecked = page

            local url = string.format(
                "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
                game.PlaceId
            )

            if cursor then
                url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
            end

            local ok, data = pcall(function()
                local response = request({
                    Url = url,
                    Method = "GET",
                })

                if not response or not response.Success then
                    error("Server list request failed")
                end

                return HttpService:JSONDecode(response.Body)
            end)

            if not ok or type(data) ~= "table"
                or type(data.data) ~= "table" then
                break
            end

            for _, server in ipairs(data.data) do
                if server.id
                    and server.id ~= game.JobId
                    and type(server.playing) == "number"
                    and type(server.maxPlayers) == "number"
                    and server.playing < server.maxPlayers then

                    local createdAt = server.createdAt or server.created
                    local createdTime

                    if type(createdAt) == "number" then
                        createdTime = createdAt
                        if createdTime > 100000000000 then
                            createdTime = math.floor(createdTime / 1000)
                        end
                    elseif type(createdAt) == "string" then
                        local okTime, parsed = pcall(function()
                            local y, m, d, h, min, sec =
                                createdAt:match(
                                    "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)"
                                )

                            if not y then
                                return nil
                            end

                            return os.time({
                                year = tonumber(y),
                                month = tonumber(m),
                                day = tonumber(d),
                                hour = tonumber(h),
                                min = tonumber(min),
                                sec = tonumber(sec),
                            })
                        end)

                        if okTime then
                            createdTime = parsed
                        end
                    end

                    table.insert(candidates, {
                        id = server.id,
                        playing = server.playing,
                        maxPlayers = server.maxPlayers,
                        createdTime = createdTime,
                    })
                end
            end

            cursor = data.nextPageCursor
            if not cursor then
                break
            end

            task.wait(0.15)
        end

        if #candidates == 0 then
            State.hopping = false
            notify("No available public servers found", Config.bad)
            return
        end

        -- Prefer servers whose timestamps are available and
        -- old enough for the selected age.
        local verified = {}

        for _, server in ipairs(candidates) do
            if server.createdTime and server.createdTime <= cutoff then
                table.insert(verified, server)
            end
        end

        local pool
        local verifiedAge = #verified > 0

        if verifiedAge then
            pool = verified

            table.sort(pool, function(a, b)
                return a.createdTime < b.createdTime
            end)
        else
            -- Public server-list responses commonly have no creation
            -- timestamp. Use the lowest population as a fallback;
            -- this does NOT prove that the server is older.
            pool = candidates

            table.sort(pool, function(a, b)
                if a.playing == b.playing then
                    return a.maxPlayers > b.maxPlayers
                end

                return a.playing < b.playing
            end)
        end

        local target = pool[1]

        if not target then
            State.hopping = false
            notify("No suitable server found", Config.bad)
            return
        end

        if verifiedAge then
            notify(
                "Found server matching age threshold (" ..
                selectedAge .. "d); checked " .. pagesChecked .. " pages",
                Config.good
            )
        else
            notify(
                "Age unavailable; using lowest-population server (" ..
                target.playing .. " players)",
                Config.muted
            )
        end

        saveConfig()

        local teleportOK, teleportError = pcall(function()
            TeleportService:TeleportToPlaceInstance(
                game.PlaceId,
                target.id,
                LocalPlayer
            )
        end)

        if not teleportOK then
            notify("Teleport failed: " .. tostring(teleportError), Config.bad)
            State.hopping = false
            return
        end

        task.delay(15, function()
            State.hopping = false
        end)
    end)
end

]=]

    return source:sub(1, startAt - 1)
        .. replacement
        .. source:sub(endAt)
end

-- Build a compact age selector.
local function createAgeSelector()
    local parent = CoreGui

    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then
            parent = hui
        end
    end

    local old = parent:FindFirstChild("AxionOldServerAgeSelector")
    if old then
        old:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "AxionOldServerAgeSelector"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = parent

    local frame = Instance.new("Frame")
    frame.Name = "AgePanel"
    frame.Size = UDim2.fromOffset(260, 112)
    frame.Position = UDim2.new(0, 18, 0.5, -56)
    frame.BackgroundColor3 = Color3.fromRGB(20, 12, 35)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(126, 70, 235)
    stroke.Thickness = 1
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -16, 0, 27)
    title.Position = UDim2.fromOffset(8, 5)
    title.BackgroundTransparency = 1
    title.Text = "AXION  /  OLD SERVER HOP"
    title.TextColor3 = Color3.fromRGB(245, 238, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -16, 0, 18)
    status.Position = UDim2.fromOffset(8, 30)
    status.BackgroundTransparency = 1
    status.Text = "Preferred age (if available)"
    status.TextColor3 = Color3.fromRGB(178, 162, 202)
    status.Font = Enum.Font.Gotham
    status.TextSize = 10
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = frame

    local selected = tonumber(ENV.AxionOldServerAge) or 7
    local buttonWidth = 55

    for index, days in ipairs({1, 3, 7, 14}) do
        local button = Instance.new("TextButton")
        button.Name = "Age" .. days
        button.Size = UDim2.fromOffset(buttonWidth, 30)
        button.Position = UDim2.fromOffset(8 + (index - 1) * 61, 57)
        button.BackgroundColor3 = days == selected
            and Color3.fromRGB(111, 64, 206)
            or Color3.fromRGB(39, 27, 57)
        button.BorderSizePixel = 0
        button.Text = tostring(days) .. "d"
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.Font = Enum.Font.GothamBold
        button.TextSize = 12
        button.Parent = frame

        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 7)
        buttonCorner.Parent = button

        button.MouseButton1Click:Connect(function()
            ENV.AxionOldServerAge = days

            for _, child in ipairs(frame:GetChildren()) do
                if child:IsA("TextButton") then
                    child.BackgroundColor3 =
                        child == button
                        and Color3.fromRGB(111, 64, 206)
                        or Color3.fromRGB(39, 27, 57)
                end
            end

            status.Text = "Preferred age: " .. days .. " days"
        end)
    end
end

local function main()
    assert(type(loadstring) == "function",
        "This executor does not support loadstring")

    local source = httpGet(LIB_URL)
    local patchedSource = buildPatchedLibrary(source)

    createAgeSelector()

    local chunk, compileError = loadstring(patchedSource)
    assert(chunk, "AxionLib compile error: " .. tostring(compileError))

    chunk()
end

local ok, err = pcall(main)

if not ok then
    warn("[Axion Old Server Hop] Error:", err)
end
