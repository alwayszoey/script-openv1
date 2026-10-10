
-- Public server discovery core
-- Requires an executor with request() and HttpService access.
-- Does not identify historical game versions.

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId

local function FindPublicServers(maxPages)
    local results = {}
    local cursor = nil

    for _ = 1, maxPages or 3 do
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
            PlaceId
        )

        if cursor then
            url ..= "&cursor=" .. HttpService:UrlEncode(cursor)
        end

        local ok, response = pcall(function()
            return request({
                Url = url,
                Method = "GET"
            })
        end)

        if not ok or not response or not response.Success then
            warn("[ServerFinder] Request failed")
            break
        end

        local parsed, body = pcall(function()
            return HttpService:JSONDecode(response.Body)
        end)

        if not parsed or type(body.data) ~= "table" then
            warn("[ServerFinder] Invalid response")
            break
        end

        for _, server in ipairs(body.data) do
            if server.id
                and server.id ~= game.JobId
                and server.playing
                and server.maxPlayers
                and server.playing < server.maxPlayers
            then
                table.insert(results, {
                    id = server.id,
                    playing = server.playing,
                    maxPlayers = server.maxPlayers
                })
            end
        end

        cursor = body.nextPageCursor
        if not cursor then
            break
        end
    end

    return results
end

local function JoinServer(server)
    assert(type(server) == "table" and server.id, "Invalid server")

    TeleportService:TeleportToPlaceInstance(
        PlaceId,
        server.id,
        LocalPlayer
    )
end

-- Example:
-- local servers = FindPublicServers(3)
-- print("Available public servers:", #servers)
-- if #servers > 0 then
--     JoinServer(servers[1])
-- end
