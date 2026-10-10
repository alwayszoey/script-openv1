--[[
    Old Server Rejoin
    Author  : @alwayszoey
    Version : 1.2.0
    Lib     : AxionLib v2.0.0
    Icons   : dist/Icons.lua
]]

local AxionLib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/alwayszoey/script-openv1/refs/heads/main/Lib/AxionLib.lua"
))()

local TeleportService = game:GetService("TeleportService")
local HttpService     = game:GetService("HttpService")
local Players         = game:GetService("Players")

local LocalPlayer     = Players.LocalPlayer
local PLACE_ID        = game.PlaceId
local PLACE_VERSION   = game.PlaceVersion
local CONFIG_NAME     = "oldserver"
local PAGE_SIZE       = 100
local MAX_PAGES       = 15

local LOGO_URL = "https://raw.githubusercontent.com/alwayszoey/script-openv1/refs/heads/main/assets/Untitled27_20261009042444.png"

local State = {
    scanning = false,
    pending  = nil,
    teleporting = false,
}

local function Notify(opts)
    if type(opts) == "string" then
        opts = { content = opts }
    end

    opts.title    = opts.title or "Old Server"
    opts.type     = opts.type  or "info"
    opts.duration = opts.duration or 3

    AxionLib:notify(opts)
end

local function IsOlder(version)
    if not version or version <= 0 then
        return false
    end
    return version < PLACE_VERSION
end

local function FormatServer(server)
    local tag = IsOlder(server.version)
        and string.format("v%d (เก่า)", server.version)
        or  string.format("v%d", server.version)

    return string.format("%d/%d  %s", server.playing, server.max, tag)
end

local function LoadConfig()
    pcall(function()
        AxionLib:loadConfig(CONFIG_NAME)
    end)

    State.pending = AxionLib.flags.oldserver_jobId or nil
end

local function SavePending(jobId, version)
    State.pending = jobId

    AxionLib.flags.oldserver_jobId   = jobId
    AxionLib.flags.oldserver_version = version

    pcall(function()
        AxionLib:saveConfig(CONFIG_NAME)
    end)
end

local function ClearPending()
    State.pending = nil

    AxionLib.flags.oldserver_jobId   = nil
    AxionLib.flags.oldserver_version = nil

    pcall(function()
        AxionLib:saveConfig(CONFIG_NAME)
    end)
end

local function FetchServers(limit, onlyOld, onProgress)
    local collected = {}
    local cursor    = ""
    local pages     = math.min(math.ceil(limit / PAGE_SIZE), MAX_PAGES)

    for page = 1, pages do
        if #collected >= limit then
            break
        end

        local ok, result = pcall(function()
            return HttpService:GetSortedAsync("Asc", PAGE_SIZE, page, PLACE_ID, "")
        end)

        local retries = 0

        while not ok and retries < 3 do
            retries = retries + 1
            task.wait(1.5)

            ok, result = pcall(function()
                return HttpService:GetSortedAsync("Asc", PAGE_SIZE, page, PLACE_ID, "")
            end)
        end

        if not ok or not result then
            return nil, "GetSortedAsync ล้มเหลว: " .. tostring(result)
        end

        local data = result:GetCurrentPage()

        if not data or #data == 0 then
            break
        end

        for _, server in ipairs(data) do
            local version = server.PlaceVersion or server.Version or 0

            if not onlyOld or IsOlder(version) then
                table.insert(collected, {
                    id      = server.Id,
                    playing = server.Playing or 0,
                    max     = server.MaxPlayers or 0,
                    version = version,
                })
            end
        end

        if onProgress then
            onProgress(#collected)
        end

        local advanced = false
        pcall(function()
            advanced = result:AdvanceToNextPageAsync()
        end)

        if not advanced then
            break
        end
    end

    return collected
end

local function FilterServers(list, minPlayers, maxPlayers)
    local out = {}

    for _, server in ipairs(list) do
        if server.playing >= minPlayers and server.playing <= maxPlayers then
            table.insert(out, server)
        end
    end

    return out
end

local function SortServers(list)
    table.sort(list, function(a, b)
        if a.version ~= b.version then
            return a.version < b.version
        end

        if a.playing ~= b.playing then
            return a.playing > b.playing
        end

        return a.id < b.id
    end)

    return list
end

local function TeleportTo(jobId)
    if State.teleporting then
        return false, "กำลังเทเลพอร์ตอยู่"
    end

    State.teleporting = true

    if queue_on_teleport then
        local source = string.format([[
            task.wait(2)
            local AxionLib = loadstring(game:HttpGet(
                "https://raw.githubusercontent.com/alwayszoey/script-openv1/refs/heads/main/Lib/AxionLib.lua"
            ))()
            pcall(function() AxionLib:loadConfig("%s") end)
        ]], CONFIG_NAME)

        pcall(queue_on_teleport, source)
    end

    local options = Instance.new("TeleportOptions")
    options.ServerInstanceId = jobId

    local ok, err = pcall(function()
        TeleportService:TeleportAsync(PLACE_ID, { LocalPlayer }, options)
    end)

    State.teleporting = false

    return ok, err
end

local function RejoinOldest(onlyOld, minPlayers, maxPlayers)
    if State.scanning then
        Notify({ content = "กำลังสแกนอยู่ กรุณารอ", type = "warning" })
        return
    end

    State.scanning = true
    Notify({ content = "กำลังสแกนเซิร์ฟเวอร์...", type = "info", duration = 2 })

    local list, err = FetchServers(200, onlyOld, function(count)
        if count > 0 and count % 50 == 0 then
            Notify({ content = "พบแล้ว " .. count .. " เซิร์ฟเวอร์", type = "info", duration = 1 })
        end
    end)

    State.scanning = false

    if not list then
        Notify({ title = "ผิดพลาด", content = err or "ไม่ทราบสาเหตุ", type = "error", duration = 5 })
        return
    end

    if #list == 0 then
        Notify({
            title    = "ไม่พบเซิร์ฟเวอร์",
            content  = onlyOld and "ทุกเซิร์ฟเวอร์เป็นเวอร์ชันล่าสุดแล้ว" or "ไม่พบเซิร์ฟเวอร์เลย",
            type     = "warning",
            duration = 4,
        })
        return
    end

    local filtered = FilterServers(list, minPlayers or 0, maxPlayers or math.huge)

    if #filtered == 0 then
        Notify({ content = "ไม่พบเซิร์ฟเวอร์ที่ตรงเงื่อนไข ใช้ทั้งหมดแทน", type = "warning" })
        filtered = list
    end

    SortServers(filtered)

    local target = filtered[1]

    SavePending(target.id, target.version)

    Notify({
        title    = "กำลังรีจอย",
        content  = string.format("%s | %s", target.id:sub(1, 12) .. "...", FormatServer(target)),
        type     = "success",
        duration = 4,
    })

    task.wait(0.5)

    local tpOk, tpErr = TeleportTo(target.id)

    if not tpOk then
        Notify({
            title    = "เทเลพอร์ตไม่สำเร็จ",
            content  = tostring(tpErr),
            type     = "error",
            duration = 5,
        })
    end
end

local function RejoinLast()
    local jobId = State.pending or AxionLib.flags.oldserver_jobId

    if not jobId or jobId == "" then
        Notify({ content = "ยังไม่มี JobId ที่บันทึกไว้", type = "warning" })
        return
    end

    Notify({
        title   = "รีจอยกลับ",
        content = jobId:sub(1, 12) .. "...",
        type    = "info",
    })

    task.wait(0.3)

    local ok, err = TeleportTo(jobId)

    if not ok then
        Notify({ title = "ผิดพลาด", content = tostring(err), type = "error", duration = 4 })
    end
end

local function RejoinRandom(onlyOld, minPlayers, maxPlayers)
    if State.scanning then
        Notify({ content = "กำลังสแกนอยู่ กรุณารอ", type = "warning" })
        return
    end

    State.scanning = true
    Notify({ content = "กำลังสแกนเซิร์ฟเวอร์...", type = "info", duration = 2 })

    local list, err = FetchServers(200, onlyOld)

    State.scanning = false

    if not list or #list == 0 then
        Notify({ title = "ไม่พบเซิร์ฟเวอร์", content = err, type = "warning" })
        return
    end

    local filtered = FilterServers(list, minPlayers or 0, maxPlayers or math.huge)

    if #filtered == 0 then
        filtered = list
    end

    local target = filtered[math.random(1, #filtered)]

    SavePending(target.id, target.version)

    Notify({
        title   = "สุ่มรีจอย",
        content = FormatServer(target),
        type    = "success",
    })

    task.wait(0.4)
    TeleportTo(target.id)
end

LoadConfig()

local Window = AxionLib:createWindow({
    title     = "Old Server Rejoin",
    subtitle  = "AxionLib v" .. AxionLib.version .. "  •  Place v" .. tostring(PLACE_VERSION),
    logoUrl   = LOGO_URL,
    toggleKey = Enum.KeyCode.RightShift,
    theme     = "Purple",
})

local RejoinTab = Window:addTab({
    name        = "Rejoin",
    icon        = "history",
    description = "หาและรีจอยเซิร์ฟเวอร์เก่า",
})

local RejoinSection = RejoinTab:addSection("สแกนและรีจอย")

RejoinSection:addLabel(string.format(
    "Place ID : %d\nเวอร์ชันปัจจุบัน : v%d",
    PLACE_ID, PLACE_VERSION
))

RejoinSection:addButton({
    name     = "รีจอยเซิร์ฟเวอร์เก่าที่เก่าสุด",
    icon     = "arrow-down-up",
    style    = "accent",
    callback = function()
        RejoinOldest(true, 0, math.huge)
    end,
})

RejoinSection:addButton({
    name     = "รีจอยเซิร์ฟเวอร์เก่าที่ว่าง",
    icon     = "user-plus",
    callback = function()
        RejoinOldest(true, 1, 12)
    end,
})

RejoinSection:addButton({
    name     = "รีจอยเซิร์ฟเวอร์เก่าแบบสุ่ม",
    icon     = "shuffle",
    callback = function()
        RejoinRandom(true, 0, math.huge)
    end,
})

RejoinSection:addButton({
    name     = "รีจอยเซิร์ฟเวอร์ล่าสุดกลับ JobId",
    icon     = "undo-2",
    callback = function()
        RejoinLast()
    end,
})

local ManageSection = RejoinTab:addSection("การจัดการ")

ManageSection:addButton({
    name     = "ล้าง JobId ที่บันทึก",
    icon     = "trash-2",
    callback = function()
        ClearPending()
        Notify({ content = "ล้าง JobId เรียบร้อย", type = "success" })
    end,
})

ManageSection:addButton({
    name     = "สแกนเซิร์ฟเวอร์ทั้งหมด (ทุกเวอร์ชัน)",
    icon     = "search",
    callback = function()
        RejoinOldest(false, 0, math.huge)
    end,
})

local FilterTab = Window:addTab({
    name        = "ตัวกรอง",
    icon        = "sliders-horizontal",
    description = "กำหนดเงื่อนไข",
})

local FilterSection = FilterTab:addSection("เงื่อนไขการเลือก")

local MinPlayersSlider = FilterSection:addSlider({
    name      = "ผู้เล่นขั้นต่ำ",
    min       = 0,
    max       = 100,
    default   = 0,
    increment = 1,
    suffix    = " คน",
    flag      = "oldserver_minPlayers",
})

local MaxPlayersSlider = FilterSection:addSlider({
    name      = "ผู้เล่นสูงสุด",
    min       = 1,
    max       = 200,
    default   = 50,
    increment = 1,
    suffix    = " คน",
    flag      = "oldserver_maxPlayers",
})

local ScanLimitSlider = FilterSection:addSlider({
    name      = "จำนวนเซิร์ฟเวอร์สูงสุด",
    min       = 50,
    max       = 1000,
    default   = 200,
    increment = 50,
    flag      = "oldserver_scanLimit",
})

FilterSection:addButton({
    name     = "ใช้เงื่อนไขนี้รีจอย",
    icon     = "filter",
    style    = "accent",
    callback = function()
        RejoinOldest(true, MinPlayersSlider:get(), MaxPlayersSlider:get())
    end,
})

local HotkeyTab = Window:addTab({
    name        = "คีย์ลัด",
    icon        = "keyboard",
    description = "ตั้งค่าปุ่มลัด",
})

local HotkeySection = HotkeyTab:addSection("ปุ่มลัด")

HotkeySection:addKeybind({
    name     = "รีจอยเซิร์ฟเวอร์เก่า",
    default  = "F8",
    flag     = "oldserver_hotkey",
    callback = function()
        RejoinOldest(true, MinPlayersSlider:get(), MaxPlayersSlider:get())
    end,
})

HotkeySection:addKeybind({
    name     = "รีจอยกลับ JobId ล่าสุด",
    default  = "F9",
    flag     = "oldserver_hotkey_rejoin",
    callback = function()
        RejoinLast()
    end,
})

HotkeySection:addLabel("กดปุ่มที่ตั้งไว้เพื่อทำงานทันที")

Window:addSettingsTab({ name = "ตั้งค่า" })

Notify({
    title    = "พร้อมใช้งาน",
    content  = "กด RightShift เพื่อเปิด/ปิด UI",
    type     = "success",
    duration = 3,
})
