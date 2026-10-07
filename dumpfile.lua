-- ============================================================
--  MapDumper.lua  |  Delta Executor  |  กดปุ่มเดียว → JSON
--  dump: workspace + ReplicatedStorage (จำกัดความลึก)
--  GUI: กล่องกลางจอ ลากได้ | dump เสร็จ → ปิดอัตโนมัติ
-- ============================================================

local HttpService       = game:GetService("HttpService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

-- ────────────────── CONFIG ──────────────────
local CONFIG = {
    OutputFile             = "MapDump.json",
    DumpWorkspace          = true,
    DumpReplicatedStorage  = true,
    DumpPlayers            = false,
    MaxDepth               = 8,       -- จำกัดความลึก กัน OOM
    MaxNodes               = 200000,  -- เพดานจำนวน node ทั้งหมด
    IncludeScripts         = false,   -- ปิดเพื่อลดขนาด dump
    IncludeAttributes      = true,
    IncludeTags            = true,
    IncludeDescendantCount = false,   -- ปิด กัน O(n^2)
    SkipClasses = {                   -- ข้าม instance ที่ไม่จำเป็น / ใหญ่มาก
        Terrain = true,
        Camera  = true,
    },
}

-- ────────────────── HELPERS ──────────────────
local function isFiniteNumber(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function round3(n)
    if not isFiniteNumber(n) then return 0 end
    return math.floor(n * 1000 + 0.5) / 1000
end

local function safeGet(inst, prop)
    local ok, val = pcall(function() return inst[prop] end)
    if not ok then return nil end
    local t = typeof(val)
    if t == "Vector3" then
        return { x = round3(val.X), y = round3(val.Y), z = round3(val.Z) }
    elseif t == "Vector2" then
        return { x = round3(val.X), y = round3(val.Y) }
    elseif t == "CFrame" then
        local p = val.Position
        local rx, ry, rz = val:ToEulerAnglesXYZ()
        return {
            pos = { x = round3(p.X), y = round3(p.Y), z = round3(p.Z) },
            rot = { x = round3(math.deg(rx)), y = round3(math.deg(ry)), z = round3(math.deg(rz)) }
        }
    elseif t == "Color3" then
        return { r = round3(val.R), g = round3(val.G), b = round3(val.B) }
    elseif t == "BrickColor" then return val.Name
    elseif t == "EnumItem"   then return val.Name
    elseif t == "Instance"   then
        local okN, n = pcall(function() return val:GetFullName() end)
        return okN and n or tostring(val)
    elseif t == "boolean" or t == "number" or t == "string" then
        return val
    else
        return tostring(val)
    end
end

-- ────────────────── PROPERTY MAP ──────────────────
local CLASS_PROPS = {
    BasePart = {
        "Position","Orientation","Size","Anchored","CanCollide","CanTouch",
        "Transparency","Material","BrickColor","Color","CastShadow",
        "AssemblyLinearVelocity","AssemblyAngularVelocity","Massless","Locked",
        "LocalTransparencyModifier","CollisionGroupId","RootPriority",
    },
    Model          = {"PrimaryPart","WorldPivot"},
    Humanoid       = {"MaxHealth","Health","WalkSpeed","JumpPower","HipHeight","RigType","DisplayName"},
    Script         = {"Enabled","RunContext"},
    LocalScript    = {"Enabled"},
    RemoteEvent    = {}, RemoteFunction = {}, BindableEvent = {}, BindableFunction = {},
    StringValue    = {"Value"}, NumberValue = {"Value"}, BoolValue = {"Value"}, IntValue = {"Value"},
    ObjectValue    = {},
    Sound          = {"SoundId","Volume","PlaybackSpeed","Playing","Looped"},
    Animation      = {"AnimationId"},
    SpecialMesh    = {"MeshType","MeshId","TextureId","Scale","Offset"},
    Texture        = {"Texture","StudsPerTileU","StudsPerTileV","Face"},
    Decal          = {"Texture","Face","Transparency"},
    SurfaceAppearance = {"AlbedoMap","NormalMap","RoughnessMap","MetalnessMap"},
    WeldConstraint = {"Part0","Part1"}, Motor6D = {"Part0","Part1","C0","C1"},
    BallSocketConstraint = {"Attachment0","Attachment1"},
    HingeConstraint = {"Attachment0","Attachment1","LimitsEnabled"},
    Attachment     = {"WorldPosition","WorldAxis"},
    Light          = {"Brightness","Color","Enabled","Range"},
    SpotLight      = {"Brightness","Color","Enabled","Range","Angle","Face"},
    PointLight     = {"Brightness","Color","Enabled","Range"},
    SurfaceLight   = {"Brightness","Color","Enabled","Range","Face"},
    Smoke          = {"Enabled","Color","Opacity","RiseVelocity","Size"},
    Fire           = {"Enabled","Color","SecondaryColor","Heat","Size"},
    Sparkles       = {"Enabled","SparkleColor"},
    BillboardGui   = {"Active","AlwaysOnTop","Size","StudsOffset"},
    ScreenGui      = {"Enabled","DisplayOrder"},
    Frame          = {"Size","Position","BackgroundColor3","BackgroundTransparency"},
    TextLabel      = {"Text","TextColor3","TextSize","Font","TextTransparency"},
    TextButton     = {"Text","TextColor3","TextSize"},
    ImageLabel     = {"Image","ImageColor3","ImageTransparency"},
    ImageButton    = {"Image","ImageColor3"},
}

local function getProps(inst)
    local result = {}
    for className, props in pairs(CLASS_PROPS) do
        local okIsA, isA = pcall(function() return inst:IsA(className) end)
        if okIsA and isA then
            for _, p in ipairs(props) do
                if result[p] == nil then
                    local v = safeGet(inst, p)
                    if v ~= nil then result[p] = v end
                end
            end
        end
    end
    return result
end

-- ────────────────── DEEP DATA HELPERS ──────────────────
local function getAttributes(inst)
    if not CONFIG.IncludeAttributes then return nil end
    local ok, attrs = pcall(function() return inst:GetAttributes() end)
    if not ok or not attrs or next(attrs) == nil then return nil end

    local result = {}
    for name, value in pairs(attrs) do
        local t = typeof(value)
        if t == "Vector3" then
            result[name] = { x = round3(value.X), y = round3(value.Y), z = round3(value.Z) }
        elseif t == "Vector2" then
            result[name] = { x = round3(value.X), y = round3(value.Y) }
        elseif t == "Color3" then
            result[name] = { r = round3(value.R), g = round3(value.G), b = round3(value.B) }
        elseif t == "CFrame" then
            local p = value.Position
            local rx, ry, rz = value:ToEulerAnglesXYZ()
            result[name] = {
                pos = { x = round3(p.X), y = round3(p.Y), z = round3(p.Z) },
                rot = { x = round3(math.deg(rx)), y = round3(math.deg(ry)), z = round3(math.deg(rz)) }
            }
        elseif t == "Instance" then
            local okN, n = pcall(function() return value:GetFullName() end)
            result[name] = okN and n or tostring(value)
        elseif t == "EnumItem" then
            result[name] = value.Name
        elseif t == "boolean" or t == "string" then
            result[name] = value
        elseif t == "number" then
            result[name] = isFiniteNumber(value) and value or 0
        else
            result[name] = tostring(value)
        end
    end
    return result
end

local function getTags(inst)
    if not CONFIG.IncludeTags then return nil end
    local ok, tags = pcall(function() return CollectionService:GetTags(inst) end)
    if not ok or not tags or #tags == 0 then return nil end
    table.sort(tags)
    return tags
end

-- ────────────────── RECURSIVE DUMP ──────────────────
local nodeCount = 0

local function dumpInstance(inst, depth)
    if depth > CONFIG.MaxDepth then return nil end
    if nodeCount >= CONFIG.MaxNodes then return nil end

    -- ข้ามคลาสที่กำหนด
    local okCls, cls = pcall(function() return inst.ClassName end)
    if okCls and CONFIG.SkipClasses[cls] then return nil end

    nodeCount = nodeCount + 1

    local node = {
        name      = inst.Name,
        className = cls or "Unknown",
        fullPath  = inst:GetFullName(),
    }

    local props = getProps(inst)
    if next(props) then node.properties = props end

    local attributes = getAttributes(inst)
    if attributes then node.attributes = attributes end

    local tags = getTags(inst)
    if tags then node.tags = tags end

    -- visibility snapshot
    local visibility = {}
    local transparency = safeGet(inst, "Transparency")
    local enabled = safeGet(inst, "Enabled")
    local localTransparency = safeGet(inst, "LocalTransparencyModifier")

    if transparency ~= nil then visibility.transparency = transparency end
    if enabled ~= nil then visibility.enabled = enabled end
    if localTransparency ~= nil then
        visibility.localTransparencyModifier = localTransparency
    end
    if next(visibility) then node.visibility = visibility end

    -- children
    local okCh, children = pcall(function() return inst:GetChildren() end)
    if okCh and children and #children > 0 then
        node.children = {}
        for _, child in ipairs(children) do
            local okChk, skip = pcall(function()
                return (not CONFIG.IncludeScripts) and
                    (child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript"))
            end)
            if not (okChk and skip) then
                local childNode = dumpInstance(child, depth + 1)
                if childNode then table.insert(node.children, childNode) end
            end
        end
        if #node.children == 0 then node.children = nil end
    end

    return node
end

-- ────────────────── JSON SAFE ENCODE ──────────────────
local function jsonSafe(value, seen)
    local valueType = typeof(value)

    if value == nil or valueType == "string" or valueType == "boolean" then
        return value
    end

    if valueType == "number" then
        return isFiniteNumber(value) and value or 0
    end

    if valueType == "Vector3" then
        return { x = round3(value.X), y = round3(value.Y), z = round3(value.Z) }
    elseif valueType == "Vector2" then
        return { x = round3(value.X), y = round3(value.Y) }
    elseif valueType == "Color3" then
        return { r = round3(value.R), g = round3(value.G), b = round3(value.B) }
    elseif valueType == "CFrame" then
        local p = value.Position
        local rx, ry, rz = value:ToEulerAnglesXYZ()
        return {
            pos = { x = round3(p.X), y = round3(p.Y), z = round3(p.Z) },
            rot = { x = round3(math.deg(rx)), y = round3(math.deg(ry)), z = round3(math.deg(rz)) }
        }
    elseif valueType == "EnumItem" then
        return value.Name
    elseif valueType == "Instance" then
        local ok, fullName = pcall(function() return value:GetFullName() end)
        return ok and fullName or tostring(value)
    end

    if valueType == "table" then
        seen = seen or {}
        if seen[value] then return "<circular>" end
        seen[value] = true

        local result = {}
        local isArray = true
        local maxIndex = 0
        local count = 0

        for k, _ in pairs(value) do
            count = count + 1
            if typeof(k) ~= "number" or k < 1 or k % 1 ~= 0 then
                isArray = false
            else
                maxIndex = math.max(maxIndex, k)
            end
        end
        if isArray and maxIndex ~= count then isArray = false end

        if isArray then
            for i = 1, maxIndex do
                result[i] = jsonSafe(value[i], seen)
            end
        else
            for k, v in pairs(value) do
                local keyType = typeof(k)
                if keyType == "string" or keyType == "number" then
                    result[tostring(k)] = jsonSafe(v, seen)
                end
            end
        end

        seen[value] = nil
        return result
    end

    local ok, str = pcall(function() return tostring(value) end)
    return ok and str or "<unsupported>"
end

-- ────────────────── MAIN DUMP ──────────────────
local function runDump(onProgress)
    local startTime = tick()
    nodeCount = 0

    local output = {
        meta = {
            game    = tostring(game.GameId),
            place   = tostring(game.PlaceId),
            version = tostring(game.PlaceVersion),
            dumped  = os.time(),
            executor = "Delta",
            mode    = "DeepDump",
            includes = {
                attributes = CONFIG.IncludeAttributes,
                tags = CONFIG.IncludeTags,
                descendantCount = CONFIG.IncludeDescendantCount,
                invisibleState = true,
            },
        },
        roots = {}
    }

    local targets = {}
    if CONFIG.DumpWorkspace         then table.insert(targets, workspace) end
    if CONFIG.DumpReplicatedStorage then table.insert(targets, game:GetService("ReplicatedStorage")) end
    if CONFIG.DumpPlayers           then table.insert(targets, game:GetService("Players")) end

    for i, root in ipairs(targets) do
        onProgress("กำลัง dump " .. root.Name .. "…", i / #targets * 0.9)
        task.wait()
        local ok, node = pcall(dumpInstance, root, 0)
        if ok and node then table.insert(output.roots, node) end
    end

    onProgress("กำลังเข้ารหัส JSON…", 0.93)
    task.wait()

    local elapsed = math.floor((tick() - startTime) * 100 + 0.5) / 100
    output.meta.dumpTimeSeconds = elapsed
    output.meta.totalNodes = nodeCount

    local safeOutput = jsonSafe(output)

    local ok2, jsonStr = pcall(function()
        return HttpService:JSONEncode(safeOutput)
    end)

    -- fallback: strip deep metadata จาก safe copy แล้ว encode อีกครั้ง
    if not ok2 then
        local function stripDeep(node)
            if type(node) ~= "table" then return node end
            node.attributes = nil
            node.tags = nil
            node.descendantCount = nil
            node.visibility = nil
            if type(node.children) == "table" then
                for _, c in ipairs(node.children) do stripDeep(c) end
            end
            return node
        end

        for _, root in ipairs(safeOutput.roots or {}) do stripDeep(root) end
        safeOutput.meta.mode = "DeepDump-Fallback"

        local okFallback, fallbackJson = pcall(function()
            return HttpService:JSONEncode(safeOutput)
        end)

        if not okFallback then
            error("ไม่สามารถสร้าง JSON ได้: " .. tostring(fallbackJson))
        end
        jsonStr = fallbackJson
    end

    onProgress("กำลังบันทึกไฟล์…", 0.97)
    task.wait()

    local ok3, err = pcall(function() writefile(CONFIG.OutputFile, jsonStr) end)
    if not ok3 then error("writefile ล้มเหลว: " .. tostring(err)) end

    return elapsed, #jsonStr
end

-- ────────────────── GUI ──────────────────
local function makeGui()
    local old = game.CoreGui:FindFirstChild("MapDumperGui")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "MapDumperGui"
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = game.CoreGui

    local W, H = 300, 190
    local panel = Instance.new("Frame")
    panel.Size             = UDim2.new(0, W, 0, H)
    panel.Position         = UDim2.new(0.5, -W/2, 0.5, -H/2)
    panel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    panel.BorderSizePixel  = 0
    panel.Parent           = sg

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 14)
    panelCorner.Parent = panel

    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(60, 90, 180)
    stroke.Thickness = 1.5
    stroke.Parent    = panel

    local titleBar = Instance.new("TextLabel")
    titleBar.Size             = UDim2.new(1, 0, 0, 40)
    titleBar.Position         = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 36)
    titleBar.BorderSizePixel  = 0
    titleBar.Text             = "📦  Map Dumper"
    titleBar.TextColor3       = Color3.fromRGB(200, 210, 255)
    titleBar.Font             = Enum.Font.GothamBold
    titleBar.TextSize         = 15
    titleBar.ZIndex           = 2
    titleBar.Parent           = panel

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 14)
    titleCorner.Parent = titleBar

    local titleFix = Instance.new("Frame")
    titleFix.Size             = UDim2.new(1, 0, 0, 14)
    titleFix.Position         = UDim2.new(0, 0, 1, -14)
    titleFix.BackgroundColor3 = Color3.fromRGB(25, 25, 36)
    titleFix.BorderSizePixel  = 0
    titleFix.ZIndex           = 1
    titleFix.Parent           = titleBar

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size                   = UDim2.new(1, -20, 0, 30)
    statusLbl.Position               = UDim2.new(0, 10, 0, 50)
    statusLbl.BackgroundTransparency = 1
    statusLbl.TextColor3             = Color3.fromRGB(160, 170, 200)
    statusLbl.Font                   = Enum.Font.Gotham
    statusLbl.TextSize               = 13
    statusLbl.TextXAlignment         = Enum.TextXAlignment.Center
    statusLbl.TextWrapped            = true
    statusLbl.Text                   = "กดปุ่มด้านล่างเพื่อเริ่ม dump"
    statusLbl.Parent                 = panel

    local barBg = Instance.new("Frame")
    barBg.Size             = UDim2.new(1, -30, 0, 10)
    barBg.Position         = UDim2.new(0, 15, 0, 90)
    barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    barBg.BorderSizePixel  = 0
    barBg.Parent           = panel

    local barBgCorner = Instance.new("UICorner")
    barBgCorner.CornerRadius = UDim.new(0, 5)
    barBgCorner.Parent = barBg

    local barFill = Instance.new("Frame")
    barFill.Size             = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(50, 130, 255)
    barFill.BorderSizePixel  = 0
    barFill.Parent           = barBg

    local barFillCorner = Instance.new("UICorner")
    barFillCorner.CornerRadius = UDim.new(0, 5)
    barFillCorner.Parent = barFill

    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1, -30, 0, 44)
    btn.Position         = UDim2.new(0, 15, 0, 115)
    btn.BackgroundColor3 = Color3.fromRGB(40, 110, 255)
    btn.TextColor3       = Color3.fromRGB(255, 255, 255)
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 15
    btn.Text             = "🚀  เริ่ม Dump Map"
    btn.AutoButtonColor  = false
    btn.Parent           = panel

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 10)
    btnCorner.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(60, 140, 255)
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(40, 110, 255)
        }):Play()
    end)

    local infoLbl = Instance.new("TextLabel")
    infoLbl.Size                   = UDim2.new(1, -20, 0, 22)
    infoLbl.Position               = UDim2.new(0, 10, 0, 162)
    infoLbl.BackgroundTransparency = 1
    infoLbl.TextColor3             = Color3.fromRGB(90, 100, 130)
    infoLbl.Font                   = Enum.Font.Gotham
    infoLbl.TextSize               = 12
    infoLbl.TextXAlignment         = Enum.TextXAlignment.Center
    infoLbl.Text                   = ""
    infoLbl.Parent                 = panel

    -- ── Drag ──
    local dragging, dragStart, startPos = false, nil, nil

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = panel.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            panel.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- ── Close (fade) ──
    local function closePanel()
        TweenService:Create(panel, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = UDim2.new(panel.Position.X.Scale, panel.Position.X.Offset,
                                 panel.Position.Y.Scale, panel.Position.Y.Offset - 40),
            BackgroundTransparency = 1,
        }):Play()

        for _, child in ipairs(panel:GetDescendants()) do
            if child:IsA("GuiObject") then
                TweenService:Create(child, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
            end
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                TweenService:Create(child, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
            end
        end

        task.delay(0.6, function() sg:Destroy() end)
    end

    -- ── Dump button ──
    local busy = false
    btn.MouseButton1Click:Connect(function()
        if busy then return end
        busy = true
        btn.Active = false

        local function onProgress(msg, pct)
            statusLbl.Text = msg
            TweenService:Create(barFill, TweenInfo.new(0.2), {
                Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
            }):Play()
            barFill.BackgroundColor3 = Color3.fromRGB(50, 130, 255)
        end

        btn.Text             = "⏳  กำลัง dump…"
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)

        task.spawn(function()
            local ok, a, b = pcall(runDump, onProgress)
            if ok then
                barFill.Back,groundColor3 = Color3.fromRGB(40, 200, 110)
                TweenService:Create(barFill, TweenInfo.new(0.3), {
                    Size = UDim2.new(1, 0, 1, 0)
                }):Play()

                statusLbl.Text       = "✅  dump สำเร็จ!"
                statusLbl.TextColor3 = Color3.fromRGB(100, 230, 150)
                infoLbl.Text         = string.format("%.2f วินาที  •  %s",
                    a (b >= 1048576 and string.format("%.2f MB", b/1048576)
                        or string.format("%.1f KB", b/1024)))
                btn.Text             = "✅  เสร็จแล้ว"
                btn.BackgroundColor3 = Color3.fromRGB(30, 170, 80)

                warn(string.format("[MapDumper] ✅ บันทึกสำเร็จ → %s (%.2f วินาที, %.1f KB)",
                    CONFIG.OutputFile, a, b/1024))

                task.wait(2)
                closePanel()
                -- ไม่เรียก game:Shutdown() เพราะไม่มีผลบน client
            else
                barFill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
                statusLbl.Text       = "❌  " .. tostring(a):sub(1, 60)
                statusLbl.TextColor3 = Color3.fromRGB(255, 120, 120)
                btn.Text             = "🔄  ลองใหม่"
                btn.BackgroundColor3 = Color3.fromRGB(40, 110, 255)
                btn.Active           = true
                busy                 = false
                warn("[MapDumper] Error:", a)
            end
        end)
    end)
end

makeGui()
