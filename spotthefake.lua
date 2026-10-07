-- ══════════════════════════════════════════════════════
--  Spot the Fake: Anime — AutoFarm  |  Rayfield UI
-- ══════════════════════════════════════════════════════

warn("[SpotFake] script start")

-- ── RAYFIELD LOADER (protected) ──────────────────────
if not loadstring then
    warn("[SpotFake] loadstring unavailable in this environment")
    return
end

local okR, RayfieldOrErr = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not okR then
    warn("[SpotFake] Rayfield fetch/load failed: " .. tostring(RayfieldOrErr))
    return
end
local Rayfield = RayfieldOrErr
if typeof(Rayfield) ~= "table" then
    warn("[SpotFake] Rayfield is not a table — URL returned bad content: " .. tostring(Rayfield))
    return
end
warn("[SpotFake] Rayfield loaded OK")

-- ── SERVICES ─────────────────────────────────────────
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local lp   = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hrp  = char:WaitForChild("HumanoidRootPart")
local hum  = char:WaitForChild("Humanoid")

-- ── CONFIG ───────────────────────────────────────────
local CFG = {
    ENABLED        = false,
    SPEED          = 100,
    COLLECT_RADIUS = 8,
    ROUND_WAIT     = 2,
    MAX_LEVEL      = 12,
    NOCLIP         = true,
    SPAWN_POS      = Vector3.new(0, 3, 0),
    GOOD_RARITIES  = {
        Legendary = true,
        Mythical  = true,
        Secret    = true,
        Divine    = true,
        Godly     = true,
        Exclusive = true,
    },
}

local LEVEL_FILTERS = {}
for i = 1,  4 do LEVEL_FILTERS[i] = { Legendary=true, Mythical=true, Secret=true, Divine=true, Godly=true, Exclusive=true } end
for i = 5,  8 do LEVEL_FILTERS[i] = { Mythical=true,  Secret=true,   Divine=true, Godly=true,  Exclusive=true } end
for i = 9, 12 do LEVEL_FILTERS[i] = { Secret=true,    Divine=true,   Godly=true,  Exclusive=true } end

-- ── STATE ────────────────────────────────────────────
local state = {
    running       = false,
    currentLevel  = 1,
    totalRounds   = 0,
    collectedGood = 0,
    spawnCached   = false,
    statusLabel   = nil,
}

-- ── UTILS ────────────────────────────────────────────
local function get_spawn()
    if state.spawnCached then return CFG.SPAWN_POS end
    for _, c in ipairs(workspace:GetChildren()) do
        if c:IsA("SpawnLocation") then
            CFG.SPAWN_POS     = c.Position + Vector3.new(0, 3, 0)
            state.spawnCached = true
            return CFG.SPAWN_POS
        end
    end
    CFG.SPAWN_POS     = hrp.Position
    state.spawnCached = true
    return CFG.SPAWN_POS
end

local function set_speed(s)
    if hum and hum.Parent then
        pcall(function() hum.WalkSpeed = s end)
    end
end

local noclipConn
local function noclip_enable()
    if noclipConn then return end
    noclipConn = RunService.Stepped:Connect(function()
        if not CFG.NOCLIP then return end
        if not char or not char.Parent then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
end
local function noclip_disable()
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
end

local function push_status(msg)
    print("[AutoFarm] " .. msg)
    if state.statusLabel then
        pcall(function()
            state.statusLabel:Set("**Status:** " .. msg)
        end)
    end
end

-- ── GAME LOGIC ───────────────────────────────────────
local function get_round_folder()
    for _, name in ipairs({"Round","RoundFolder","CurrentRound","Game","Map"}) do
        local f = workspace:FindFirstChild(name)
        if f then return f end
    end
    for _, child in ipairs(workspace:GetChildren()) do
        if (child:IsA("Folder") or child:IsA("Model"))
            and (child:GetAttribute("Level") or child:GetAttribute("Stage")) then
            return child
        end
    end
end

local function get_current_level()
    local stats = lp:FindFirstChild("leaderstats")
    if stats then
        local v = stats:FindFirstChild("Level")
                or stats:FindFirstChild("Stage")
                or stats:FindFirstChild("Round")
        if v then return tonumber(v.Value) or 1 end
    end
    local rf = get_round_folder()
    if rf then
        local a = rf:GetAttribute("Level") or rf:GetAttribute("Stage")
        if a then return tonumber(a) or 1 end
    end
    return state.currentLevel
end

local function get_rarity(model)
    local a = model:GetAttribute("Rarity")
           or model:GetAttribute("rarity")
           or model:GetAttribute("Tier")
    if a then return tostring(a) end

    local v = model:FindFirstChild("Rarity") or model:FindFirstChild("rarity")
    if v and v:IsA("StringValue") then return v.Value end

    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("TextLabel") and d.Name:lower():find("rarity") then
            return d.Text
        end
    end
end

local function is_worth_keeping(model, level)
    local r = get_rarity(model)
    if not r then return false end
    r = r:gsub("[%[%]%(%)%d%%]", ""):match("^%s*(.-)%s*$")
    if not r or r == "" then return false end
    local filter = LEVEL_FILTERS[level] or CFG.GOOD_RARITIES
    return filter[r] == true
end

local function find_real_character(roundFolder)
    for _, obj in ipairs(roundFolder:GetDescendants()) do
        if obj:IsA("Model") then
            local a = obj:GetAttribute("IsReal") or obj:GetAttribute("Real") or obj:GetAttribute("Correct")
            if a == true then return obj end

            local bv = obj:FindFirstChild("IsReal") or obj:FindFirstChild("Real")
            if bv and bv:IsA("BoolValue") and bv.Value then return obj end

            local nl = obj.Name:lower()
            if nl:find("real") and not nl:find("fake") then return obj end
        end
    end

    local candidates = {}
    for _, obj in ipairs(roundFolder:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildWhichIsA("Humanoid") then
            table.insert(candidates, obj)
        end
    end
    if #candidates == 1 then return candidates[1] end

    for _, m in ipairs(candidates) do
        for _, d in ipairs(m:GetDescendants()) do
            if d:IsA("BodyVelocity") or d:IsA("BodyPosition") then return m end
        end
    end

    return candidates[1]
end

-- ── INTERACT (Delta-aware) ───────────────────────────
local function fire_prompt(pp)
    if fireproximityprompt then
        pcall(function() fireproximityprompt(pp) end)
    else
        pcall(function()
            pp:InputHoldBegin()
            task.wait(pp.HoldDuration or 0)
            pp:InputHoldEnd()
        end)
    end
end

local function fire_click(cd)
    if fireclickdetector then
        pcall(function() fireclickdetector(cd) end)
    end
end

local function interact_with(target)
    local root = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
    if not root then return false end

    hrp.CFrame = CFrame.new(root.Position + Vector3.new(0, 0, 3))
    task.wait(0.1)

    local cd = target:FindFirstChildWhichIsA("ClickDetector", true)
    if cd then fire_click(cd); return true end

    local pp = target:FindFirstChildWhichIsA("ProximityPrompt", true)
    if pp then fire_prompt(pp); return true end

    for _ = 1, 3 do
        if not hrp or not hrp.Parent then break end
        hrp.CFrame = CFrame.new(root.Position + Vector3.new(0, 1, 0))
        task.wait(0.05)
    end
    return true
end

local function collect_nearby_drops()
    local myPos = hrp and hrp.Position
    if not myPos then return end

    for _, fname in ipairs({"Drops","Rewards","Characters","Collectibles","Orbs"}) do
        local folder = workspace:FindFirstChild(fname)
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                local pos
                if item:IsA("Model") and item.PrimaryPart then
                    pos = item.PrimaryPart.Position
                elseif item:IsA("BasePart") then
                    pos = item.Position
                end
                if pos and (myPos - pos).Magnitude <= CFG.COLLECT_RADIUS then
                    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
                    task.wait(0.05)
                    myPos = hrp.Position
                end
            end
        end
    end

    for _, obj in ipairs(workspace:GetChildren()) do
        local tag = obj:GetAttribute("IsPickup") or obj:GetAttribute("Collectible")
        if tag then
            local pos
            if obj:IsA("Model") and obj.PrimaryPart then pos = obj.PrimaryPart.Position
            elseif obj:IsA("BasePart") then pos = obj.Position end
            if pos and (myPos - pos).Magnitude <= CFG.COLLECT_RADIUS then
                hrp.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
                task.wait(0.05)
                myPos = hrp.Position
            end
        end
    end
end

-- ── MAIN FARM LOOP ───────────────────────────────────
local function run_farm()
    if state.running then return end
    state.running = true
    set_speed(CFG.SPEED)
    if CFG.NOCLIP then noclip_enable() end
    local spawnPos = get_spawn()
    push_status("Farm started")

    while state.running and CFG.ENABLED do
        if not hrp or not hrp.Parent or not hum or not hum.Parent then
            task.wait(0.5)
            continue
        end

        local level = get_current_level()
        state.currentLevel = level

        if level > CFG.MAX_LEVEL then
            push_status("All levels done — idle at spawn")
            hrp.CFrame = CFrame.new(spawnPos)
            task.wait(5)
            continue
        end

        push_status(("Lvl %d | Rounds: %d | Good: %d"):format(
            level, state.totalRounds, state.collectedGood))

        local rf = get_round_folder()
        if not rf then task.wait(0.15); continue end

        local realChar = find_real_character(rf)
        if realChar then
            interact_with(realChar)
            task.wait(0.3)
            collect_nearby_drops()
            state.totalRounds += 1
        end

        task.wait(CFG.ROUND_WAIT)
    end

    if hrp and hrp.Parent then
        hrp.CFrame = CFrame.new(get_spawn())
    end
    set_speed(16)
    noclip_disable()
    state.running = false
    push_status("Stopped")
end

-- ── RESPAWN HANDLER ──────────────────────────────────
lp.CharacterAdded:Connect(function(nc)
    char = nc
    hrp  = nc:WaitForChild("HumanoidRootPart")
    hum  = nc:WaitForChild("Humanoid")
    state.spawnCached = false
    if CFG.ENABLED and not state.running then
        task.wait(1)
        task.spawn(run_farm)
    end
end)

-- ══════════════════════════════════════════════════════
--  RAYFIELD UI
-- ══════════════════════════════════════════════════════
warn("[SpotFake] building UI...")

local okW, WindowOrErr = pcall(function()
    return Rayfield:CreateWindow({
        Name                   = "Spot the Fake - Anime",
        Icon                   = 4483362458,
        LoadingTitle           = "Anime AutoFarm",
        LoadingSubtitle        = "by spinach",
        Theme                  = "Default",
        DisableRayfieldPrompts = false,
        DisableBuildWarnings   = true,
        ConfigurationSaving    = { Enabled = false },
        KeySystem              = false,
    })
end)
if not okW then
    warn("[SpotFake] CreateWindow failed: " .. tostring(WindowOrErr))
    return
end
local Window = WindowOrErr
warn("[SpotFake] window created OK")

local okT, TabOrErr = pcall(function()
    return Window:CreateTab("Auto Farm", 4483362458)
end)
if not okT then
    warn("[SpotFake] CreateTab failed: " .. tostring(TabOrErr))
    return
end
local TabMain = TabOrErr

-- ── TAB: Auto Farm ───────────────────────────────────
local StatusEl = TabMain:CreateParagraph({
    Title   = "Status",
    Content = "**Status:** Waiting to start...",
})
state.statusLabel = StatusEl

TabMain:CreateToggle({
    Name         = "Enable AutoFarm",
    CurrentValue = false,
    Flag         = "FarmEnabled",
    Callback     = function(val)
        CFG.ENABLED = val
        if val and not state.running then
            task.spawn(run_farm)
        else
            state.running = false
        end
    end,
})

TabMain:CreateDivider()

TabMain:CreateSlider({
    Name         = "Walk Speed",
    Range        = {16, 250},
    Increment    = 2,
    Suffix       = "studs/s",
    CurrentValue = 100,
    Flag         = "WalkSpeed",
    Callback     = function(val)
        CFG.SPEED = val
        if state.running then set_speed(val) end
    end,
})

TabMain:CreateSlider({
    Name         = "Collect Radius",
    Range        = {4, 30},
    Increment    = 1,
    Suffix       = "studs",
    CurrentValue = 8,
    Flag         = "CollectRadius",
    Callback     = function(val) CFG.COLLECT_RADIUS = val end,
})

TabMain:CreateSlider({
    Name         = "Round Delay",
    Range        = {0.5, 10},
    Increment    = 0.5,
    Suffix       = "sec",
    CurrentValue = 2,
    Flag         = "RoundDelay",
    Callback     = function(val) CFG.ROUND_WAIT = val end,
})

TabMain:CreateDivider()

TabMain:CreateToggle({
    Name         = "NoClip",
    CurrentValue = true,
    Flag         = "Noclip",
    Callback     = function(val)
        CFG.NOCLIP = val
        if val then noclip_enable() else noclip_disable() end
    end,
})

TabMain:CreateButton({
    Name     = "Return to Spawn Now",
    Callback = function()
        if hrp and hrp.Parent then
            hrp.CFrame = CFrame.new(get_spawn())
        end
        push_status("Teleported to spawn.")
    end,
})

-- ── TAB: Rarity Filter ───────────────────────────────
local TabRarity = Window:CreateTab("Rarity Filter", 4483362458)

TabRarity:CreateParagraph({
    Title   = "Level Presets",
    Content = "Lv 1-4: Legendary+  |  Lv 5-8: Mythical+  |  Lv 9-12: Secret+",
})

TabRarity:CreateDivider()

local rarityList = {
    { name = "Legendary", flag = "RarityLegendary" },
    { name = "Mythical",  flag = "RarityMythical"  },
    { name = "Secret",    flag = "RaritySecret"    },
    { name = "Divine",    flag = "RarityDivine"    },
    { name = "Godly",     flag = "RarityGodly"     },
    { name = "Exclusive", flag = "RarityExclusive" },
}

for _, r in ipairs(rarityList) do
    TabRarity:CreateToggle({
        Name         = r.name,
        CurrentValue = CFG.GOOD_RARITIES[r.name] or false,
        Flag         = r.flag,
        Callback     = function(val)
            CFG.GOOD_RARITIES[r.name] = val
            for _, filter in pairs(LEVEL_FILTERS) do
                if val then
                    filter[r.name] = true
                else
                    filter[r.name] = nil
                end
            end
        end,
    })
end

-- ── TAB: Stats ───────────────────────────────────────
local TabStats = Window:CreateTab("Stats", 4483362458)

local StatsEl = TabStats:CreateParagraph({
    Title   = "Session Stats",
    Content = "No data yet.",
})

task.spawn(function()
    while true do
        task.wait(3)
        pcall(function()
            StatsEl:Set(
                ("**Level:** %d / %d\n**Rounds:** %d\n**Good:** %d\n**Running:** %s")
                :format(
                    state.currentLevel,
                    CFG.MAX_LEVEL,
                    state.totalRounds,
                    state.collectedGood,
                    tostring(state.running)
                )
            )
        end)
    end
end)

TabStats:CreateButton({
    Name     = "Reset Stats",
    Callback = function()
        state.totalRounds   = 0
        state.collectedGood = 0
        push_status("Stats reset.")
        pcall(function()
            Rayfield:Notify({
                Title    = "Stats Reset",
                Content  = "Counters cleared.",
                Duration = 3,
                Image    = 4483362458,
            })
        end)
    end,
})

-- ── TAB: Settings ────────────────────────────────────
local TabSettings = Window:CreateTab("Settings", 4483362458)

TabSettings:CreateSlider({
    Name         = "Max Level",
    Range        = {1, 12},
    Increment    = 1,
    Suffix       = "",
    CurrentValue = 12,
    Flag         = "MaxLevel",
    Callback     = function(val) CFG.MAX_LEVEL = val end,
})

TabSettings:CreateDivider()

TabSettings:CreateButton({
    Name     = "Destroy UI",
    Callback = function()
        CFG.ENABLED   = false
        state.running = false
        pcall(function() Rayfield:Destroy() end)
    end,
})

-- ── READY NOTIFICATION ───────────────────────────────
pcall(function()
    Rayfield:Notify({
        Title    = "Spot the Fake - Anime",
        Content  = "UI loaded. Toggle AutoFarm to begin.",
        Duration = 5,
        Image    = 4483362458,
    })
end)

warn("[SpotFake] done")
