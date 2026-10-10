-- Hop server until a server with an OLDER PlaceVersion is found, then stop.
-- Run once; it re-launches itself after every teleport via queue_on_teleport.

local CONFIG = [==[
return {
    REFERENCE_VERSION = 36130, -- version you consider "current"; any server below this (or below the highest seen) counts as old
    MAX_HOPS = 40,             -- safety limit
    FILE_STATE = "hop_old_state.json",
    FILE_SELF = "hop_old_server.lua",
}
]==]

local MAIN = [==[
local C = loadstring(readfile("hop_old_config.lua"))()
local HS = game:GetService("HttpService")
local TS = game:GetService("TeleportService")
local Players = game:GetService("Players")
local req = (syn and syn.request) or http_request or request
local q = queue_on_teleport or (syn and syn.queue_on_teleport)

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(3)

local st = {versions = {}, tried = {}, retried = {}, hops = 0, status = "running", ref = C.REFERENCE_VERSION}
if isfile(C.FILE_STATE) then
    local ok, d = pcall(function() return HS:JSONDecode(readfile(C.FILE_STATE)) end)
    if ok and type(d) == "table" then st = d end
end
local function save() writefile(C.FILE_STATE, HS:JSONEncode(st)) end
if st.status ~= "running" then return end

-- record this server
local ver = game.PlaceVersion
st.versions[game.JobId] = ver
st.tried[game.JobId] = true
local ref = st.ref or C.REFERENCE_VERSION
for _, v in pairs(st.versions) do if v > ref then ref = v end end
st.ref = ref

-- found an older server -> stop
if ver < ref then
    st.status = "found"; st.foundJobId = game.JobId; st.foundVersion = ver
    save()
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Old server found",
            Text = "PlaceVersion " .. ver .. " (newer: " .. ref .. ")",
            Duration = 30,
        })
    end)
    print("[HOP] FOUND old server:", game.JobId, "version", ver)
    return
end

if q then q('loadstring(readfile("' .. C.FILE_SELF .. '"))()') end

-- if we saw an older server earlier, try to return to it once
for id, v in pairs(st.versions) do
    if v < ref and id ~= game.JobId and not st.retried[id] then
        st.retried[id] = true; save()
        TS:TeleportToPlaceInstance(game.PlaceId, id, Players.LocalPlayer)
        return
    end
end

if st.hops >= C.MAX_HOPS then
    st.status = "stopped"; st.note = "max hops"; save()
    print("[HOP] stopped: max hops reached")
    return
end

-- collect candidate servers
local cands, cursor = {}, nil
for _ = 1, 3 do
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"
    if cursor then url = url .. "&cursor=" .. cursor end
    local ok, res = pcall(req, {Url = url, Method = "GET"})
    if not ok or res.StatusCode ~= 200 then break end
    local body = HS:JSONDecode(res.Body)
    for _, s in ipairs(body.data or {}) do
        if s.id ~= game.JobId and not st.tried[s.id] and s.playing < s.maxPlayers then
            table.insert(cands, s.id)
        end
    end
    cursor = body.nextPageCursor
    if not cursor then break end
end

if #cands == 0 then
    st.status = "stopped"; st.note = "no candidates"; save()
    print("[HOP] stopped: no more servers to try")
    return
end

local pick = cands[math.random(#cands)]
st.tried[pick] = true
st.hops = st.hops + 1
save()
print(("[HOP] #%d version %d (ref %d) -> %s"):format(st.hops, ver, ref, pick))

TS.TeleportInitFailed:Connect(function()
    task.wait(2)
    loadstring(readfile("hop_old_server.lua"))()
end)
TS:TeleportToPlaceInstance(game.PlaceId, pick, Players.LocalPlayer)
]==]

-- install + start (fresh run: clears old state)
writefile("hop_old_config.lua", CONFIG)
writefile("hop_old_server.lua", MAIN)
if isfile("hop_old_state.json") then delfile("hop_old_state.json") end
loadstring(MAIN)()

-- To stop manually:  writefile("hop_old_state.json", '{"status":"stopped","versions":{},"tried":{},"retried":{},"hops":0}')
-- To read the result: print(readfile("hop_old_state.json"))
