-- ══════════════════════════════════════════════════════
--  Spot the Fake: Anime — AutoFarm  |  Rayfield UI
-- ══════════════════════════════════════════════════════

-- ── RAYFIELD LOADER ──────────────────────────────────
local Rayfield = loadstring(game:HttpGet(
    "https://sirius.menu/rayfield"
))()

-- ── SERVICES ─────────────────────────────────────────
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local TweenService  = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local lp   = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hrp  = char:WaitForChild("HumanoidRootPart")
local hum  = char:WaitForChild("Humanoid")

-- ── CONFIG (เชื่อมกับ UI) ─────────────────────────────
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
    statusLabel   = nil,   -- Rayfield label ref
}

-- ── UTILS ────────────────────────────────────────────
local function get_spawn()
    if state.spawnCached then return CFG.SPAWN_POS end
    for _, c in ipairs(workspace:GetChildren()) do
        if c:IsA("SpawnLocation") then
            CFG.SPAWN_POS   = c.Position + Vector3.new(0, 3, 0)
            state.spawnCached = true
            return CFG.SPAWN_POS
        end
    end
    CFG.SPAWN_POS   = hrp.Position
    state.spawnCached = true
    return CFG.SPAWN_POS
end

local function set_speed(s) hum.WalkSpeed = s end

local noclipConn
local function noclip_enable()
    if noclipConn then return end
    noclipConn = RunService.Stepped:Connect(function()
        if not CFG.NOCLIP then return end
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
    -- update Rayfield paragraph if ref exists
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
    r = r:gsub("[%[%]%(%)%d%%]",""):match("^%s*(.-)%s*$")
    return (LEVEL_FILTERS[level] or CFG.GOOD_RARITIES)[r] == true
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
end

local function interact_with(target)
    local root = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
    if not root then return end
    hrp.CFrame = CFrame.new(root.Position + Vector3.new(0,0,3))
    task.wait(0.1)
    local cd = target:FindFirstChildWhichIsA("ClickDetector",true)
    if cd then fireclickdetector(cd); return end
    local pp = target:FindFirstChildWhichIsA("ProximityPrompt",true)
    if pp then fireproximityprompt(pp); return end
    for i = 1, 3 do
        hrp.CFrame = CFrame.new(root.Position + Vector3.new(0,1,0))
        task.wait(0.05)
    end
end

local function collect_nearby_drops()
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
                if pos and (hrp.Position - pos).Magnitude <= CFG.COLLECT_RADIUS then
                    hrp.CFrame = CFrame.new(pos + Vector3.new(0,2,0))
                    task.wait(0.05)
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
            if pos and (hrp.Position - pos).Magnitude <= CFG.COLLECT_RADIUS then
                hrp.CFrame = CFrame.new(pos + Vector3.new(0,2,0))
                task.wait(0.05)
            end
        end
    end
end

-- ── MAIN FARM LOOP ───────────────────────────────────
local function run_farm()
    state.running = true
    set_speed(CFG.SPEED)
    if CFG.NOCLIP then noclip_enable() end
    local spawnPos = get_spawn()
    push_status("Farm started ▶")

    while state.running and CFG.ENABLED do
        local level = get_current_level()
        state.currentLevel = level

        if level > CFG.MAX_LEVEL then
            push_status("All levels done — idle at spawn")
            hrp.CFrame = CFrame.new(spawnPos)
            task.wait(5)
            continue
        end

        push_status(("Level %d | Rounds: %d | Good: %d"):format(
            level, state.totalRounds, state.collectedGood))

        local rf = get_round_folder()
        if not rf then task.wait(0.15); continue end

        local realChar = find_real_character(rf)
        if realChar then
            interact_with(realChar)
            task.wait(0.3)
            collect_nearby_drops()

            local dropsFolder = workspace:FindFirstChild("Drops")
                             or workspace:FindFirstChild("Rewards")
            if dropsFolder then
                for _, drop in ipairs(dropsFolder:GetChildren()) do
                    if drop:IsA("Model") and is_worth_keeping(drop, level) then
                        interact_with(drop)
                        state.collectedGood += 1
                        push_status(("✓ Kept %s [Lvl %d] — Total: %d"):format(
                            drop.Name, level, state.collectedGood))
                    end
                end
            end
            state.totalRounds += 1
        end

        task.wait(CFG.ROUND_WAIT)
    end

    -- return to spawn on stop
    hrp.CFrame = CFrame.new(get_spawn())
    set_speed(16)
    noclip_disable()
    state.running = false
    push_status("Stopped — returned to spawn ✦")
end

-- ── RESPAWN HANDLER ──────────────────────────────────
lp.CharacterAdded:Connect(function(nc)
    char = nc
    hrp  = nc:WaitForChild("HumanoidRootPart")
    hum  = nc:WaitForChild("Humanoid")
    state.spawnCached = false
    if CFG.ENABLED then
        state.running = false
        task.wait(1)
        task.spawn(run_farm)
    end
end)

-- ══════════════════════════════════════════════════════
--  RAYFIELD UI
-- ══════════════════════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name             = "Spot the Fake • Anime",
    Icon             = 0,          -- Rayfield default icon
    LoadingTitle     = "Anime AutoFarm",
    LoadingSubtitle  = "by spinach",
    Theme            = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings   = true,
    ConfigurationSaving = {
        Enabled  = true,
        FileName = "SpotFakeAnime",
    },
    KeySystem = false,
})

-- ── TAB: Main ────────────────────────────────────────
local TabMain = Window:CreateTab("⚔️ Auto Farm", 4483362458)

-- Status paragraph (live)
local StatusEl = TabMain:CreateParagraph({
    Title     = "Status",
    Content   = "**Status:** Waiting to start...",
})
state.statusLabel = StatusEl

-- Master toggle
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
            CFG.ENABLED   = false
        end
    end,
})

TabMain:CreateDivider()

-- Speed slider
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

-- Collect radius slider
TabMain:CreateSlider({
    Name         = "Collect Radius",
    Range        = {4, 30},
    Increment    = 1,
    Suffix       = "studs",
    CurrentValue = 8,
    Flag         = "CollectRadius",
    Callback     = function(val)
        CFG.COLLECT_RADIUS = val
    end,
})

-- Round wait slider
TabMain:CreateSlider({
    Name         = "Round Delay",
    Range        = {0.5, 10},
    Increment    = 0.5,
    Suffix       = "sec",
    CurrentValue = 2,
    Flag         = "RoundDelay",
    Callback     = function(val)
        CFG.ROUND_WAIT = val
    end,
})

TabMain:CreateDivider()

-- Noclip toggle
TabMain:CreateToggle({
    Name         = "NoClip",
    CurrentValue = true,
    Flag         = "Noclip",
    Callback     = function(val)
        CFG.NOCLIP = val
        if val then noclip_enable() else noclip_disable() end
    end,
})

-- Return to spawn button
TabMain:CreateButton({
    Name     = "Return to Spawn Now",
    Callback = function()
        hrp.CFrame = CFrame.new(get_spawn())
        push_status("Teleported to spawn manually.")
    end,
})

-- ── TAB: Rarity Filter ───────────────────────────────
local TabRarity = Window:CreateTab("⭐ Rarity Filter", 4483362458)

TabRarity:CreateParagraph({
    Title   = "Level Presets",
    Content = "Lv 1-4: Legendary+  •  Lv 5-8: Mythical+  •  Lv 9-12: Secret+",
})

TabRarity:CreateDivider()

local rarityList = {
    { name = "Legendary",  flag = "RarityLegendary" },
    { name = "Mythical",   flag = "RarityMythical"  },
    { name = "Secret",     flag = "RaritySecret"    },
    { name = "Divine",     flag = "RarityDivine"    },
    { name = "Godly",      flag = "RarityGodly"     },
    { name = "Exclusive",  flag = "RarityExclusive" },
}

for _, r in ipairs(rarityList) do
    TabRarity:CreateToggle({
        Name         = r.name,
        CurrentValue = CFG.GOOD_RARITIES[r.name] or false,
        Flag         = r.flag,
        Callback     = function(val)
            CFG.GOOD_RARITIES[r.name] = val
            -- sync into level filters
            for lvl, filter in pairs(LEVEL_FILTERS) do
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
local TabStats = Window:CreateTab("📊 Stats", 4483362458)

local StatsEl = TabStats:CreateParagraph({
    Title   = "Session Stats",
    Content = "No data yet.",
})

-- refresh stats every 3 s
task.spawn(function()
    while true do
        task.wait(3)
        pcall(function()
            StatsEl:Set(
                ("**Level:** %d / %d\n**Rounds:** %d\n**Good Characters:** %d\n**Running:** %s")
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
        Rayfield:Notify({
            Title    = "Stats Reset",
            Content  = "Round counter and good-character count cleared.",
            Duration = 3,
        })
    end,
})

-- ── TAB: Settings ────────────────────────────────────
local TabSettings = Window:CreateTab("⚙️ Settings", 4483362458)

TabSettings:CreateSlider({
    Name         = "Max Level",
    Range        = {1, 12},
    Increment    = 1,
    Suffix       = "",
    CurrentValue = 12,
    Flag         = "MaxLevel",
    Callback     = function(val)
        CFG.MAX_LEVEL = val
    end,
})

TabSettings:CreateDivider()

TabSettings:CreateButton({
    Name     = "Destroy UI",
    Callback = function()
        CFG.ENABLED   = false
        state.running = false
        Rayfield:Destroy()
    end,
})

-- ── READY NOTIFICATION ───────────────────────────────
Rayfield:Notify({
    Title    = "Spot the Fake • Anime",
    Content  = "UI loaded. Toggle Auto Farm to begin.",
    Duration = 5,
    Image    = 4483362458,
})

Rayfield:LoadConfiguration()
