-- ============================================================
--  MapDumper.lua  |  Delta Executor
--  dump: workspace + ReplicatedStorage (จำกัดความลึก)
--  รูปแบบ: JSON / TXT  |  ตั้งชื่อไฟล์ได้ (ว่าง = ใช้ชื่อ map อัตโนมัติ)
-- ============================================================

warn("[MapDumper] script started")

local HttpService       = game:GetService("HttpService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")

-- ────────────────── CONFIG ──────────────────
local CONFIG = {
    DefaultFileName        = "",        -- ว่าง = ใช้ชื่อ map อัตโนมัติ
    DefaultFormat          = "json",    -- "json" หรือ "txt"
    DumpWorkspace          = true,
    DumpReplicatedStorage  = true,
    DumpPlayers            = false,
    MaxDepth               = 8,
    MaxNodes               = 200000,
    IncludeScripts         = false,
    IncludeAttributes      = true,
    IncludeTags            = true,
    IncludeDescendantCount = false,
    SkipClasses = {
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

-- sanitize ชื่อไฟล์: ตัดอักขระต้องห้ามของ filesystem
local function sanitizeFileName(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil end
    -- ตัดอักขระต้องห้าม: \ / : * ? " < > | และควบคุม
    name = name:gsub('[\\/:*?"<>|]', "_")
    name = name:gsub("%c", "")
    name = name:gsub("%.%.", "_")        -- กัน path traversal
    if #name > 100 then name = name:sub(1, 100) end
    if name == "" then return nil end
    return name
end

-- ดึงชื่อ map จาก DataModel แล้ว sanitize
local function getMapName()
    local raw = game:GetService("MarketplaceService")
    -- พยายามดึงชื่อเกมจริงก่อน
    local okName, info = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    end)
    if okName and info and info.Name and info.Name ~= "" then
        return sanitizeFileName(info.Name) or ("Map_" .. tostring(game.PlaceId))
    end
    -- fallback: ใช้ชื่อ place file ปัจจุบัน
    local okFile, fileName = pcall(function()
        return game:GetService("Players").LocalPlayer and game.PlaceId
    end)
    if okFile and fileName then
        return "Map_" .. tostring(fileName)
    end
    return "MapDump"
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

-- ────────────────── TXT ENCODER ──────────────────
-- แปลง node tree เป็น text แบบ indent อ่านง่าย
local function encodeTxt(node, indent, out)
    indent = indent or 0
    out = out or {}

    local pad = string.rep("  ", indent)
    local header = pad .. "[" .. node.className .. "] " .. node.name
    table.insert(out, header)

    if node.properties and next(node.properties) then
        -- เรียง key ให้อ่านง่าย
        local keys = {}
        for k, _ in pairs(node.properties) do table.insert(keys, k) end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local v = node.properties[k]
            local vs
            if type(v) == "table" then
                local parts = {}
                for kk, vv in pairs(v) do
                    table.insert(parts, tostring(kk) .. "=" .. tostring(vv))
                end
                vs = "{" .. table.concat(parts, ", ") .. "}"
            else
                vs = tostring(v)
            end
            table.insert(out, pad .. "  ." .. k .. " = " .. vs)
        end
    end

    if node.attributes then
        local keys = {}
        for k, _ in pairs(node.attributes) do table.insert(keys, k) end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local v = node.attributes[k]
            local vs
            if type(v) == "table" then
                local parts = {}
                for kk, vv in pairs(v) do
                    table.insert(parts, tostring(kk) .. "=" .. tostring(vv))
                end
                vs = "{" .. table.concat(parts, ", ") .. "}"
            else
                vs = tostring(v)
            end
            table.insert(out, pad .. "  @" .. k .. " = " .. vs)
        end
    end

    if node.tags then
        table.insert(out, pad .. "  #tags = " .. table.concat(node.tags, ", "))
    end

    if node.visibility then
        local parts = {}
        for k, v in pairs(node.visibility) do
            table.insert(parts, k .. "=" .. tostring(v))
        end
        if #parts > 0 then
            table.insert(out, pad .. "  ~visibility: " .. table.concat(parts, ", "))
        end
    end

    if node.children then
        for _, child in ipairs(node.children) do
            encodeTxt(child, indent + 1, out)
        end
    end

    return out
end

local function buildTxtOutput(output)
    local lines = {}

    table.insert(lines, "============================================")
    table.insert(lines, "  MAP DUMP  |  " .. tostring(output.meta.game))
    table.insert(lines, "============================================")
    table.insert(lines, "game:        " .. tostring(output.meta.game))
    table.insert(lines, "place:       " .. tostring(output.meta.place))
    table.insert(lines, "version:     " .. tostring(output.meta.version))
    table.insert(lines, "dumped:      " .. tostring(output.meta.dumped))
    table.insert(lines, "mode:        " .. tostring(output.meta.mode))
    table.insert(lines, "totalNodes:  " .. tostring(output.meta.totalNodes or 0))
    table.insert(lines, "")

    for _, root in ipairs(output.roots or {}) do
        table.insert(lines, "───────── ROOT: " .. root.name .. " ─────────")
        encodeTxt(root, 0, lines)
        table.insert(lines, "")
    end

    return table.concat(lines, "\n")
end

-- ────────────────── MAIN DUMP ──────────────────
local function runDump(onProgress, format, userFileName)
    local startTime = tick()
    nodeCount = 0

    -- คำนวณชื่อไฟล์: ถ้าผู้ใช้ตั้งไว้ใช้ค่านั้น ไม่งั้นดึงจากชื่อ map
    local baseName = sanitizeFileName(userFileName)
    if not baseName then
        baseName = getMapName()
    end
    local ext = (format == "txt") and ".txt" or ".json"
    local fileName = baseName .. ext

    local output = {
        meta = {
            game    = tostring(game.GameId),
            place   = tostring(game.PlaceId),
            version = tostring(game.PlaceVersion),
            dumped  = os.time(),
            executor = "Delta",
            mode    = "DeepDump",
            format  = format,
            fileName = fileName,
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
    if CONFIG.DumpPlayers           then table.insert(targets, Players) end

    for i, root in ipairs(targets) do
        onProgress("กำลัง dump " .. root.Name .. "…", i / #targets * 0.9)
        task.wait()
        local ok, node = pcall(dumpInstance, root, 0)
        if ok and node then table.insert(output.roots, node) end
    end

    onProgress("กำลังเข้ารหัส…", 0.93)
    task.wait()

    local elapsed = math.floor((tick() - startTime) * 100 + 0.5) / 100
    output.meta.dumpTimeSeconds = elapsed
    output.meta.totalNodes = nodeCount

    local finalStr

    if format == "txt" then
        -- ── TXT ──
        local okTxt, txt = pcall(buildTxtOutput, output)
        if not okTxt then error("สร้าง TXT ล้มเหลว: " .. tostring(txt)) end
        finalStr = txt
    else
        -- ── JSON ──
        local safeOutput = jsonSafe(output)

        local ok2, jsonStr = pcall(function()
            return HttpService:JSONEncode(safeOutput)
        end)

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

        finalStr = jsonStr
    end

    onProgress("กำลังบันทึกไฟล์…", 0.97)
    task.wait()

    local ok3, err = pcall(function() writefile(fileName, finalStr) end)
    if not ok3 then error("writefile ล้มเหลว: " .. tostring(err)) end

    return elapsed, #finalStr, fileName
end

-- ────────────────── GUI ──────────────────
local function makeGui()
    local parentGui
    local okPG, pg = pcall(function()
        return Players.LocalPlayer:WaitForChild("PlayerGui", 5)
    end)
    if okPG and pg then
        parentGui = pg
    else
        local okCG, cg = pcall(function() return game.CoreGui end)
        if okCG and cg then
            parentGui = cg
        else
            warn("[MapDumper] หา GUI parent ไม่ได้")
            return
        end
    end

    local old = parentGui:FindFirstChild("MapDumperGui")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "MapDumperGui"
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder   = 999
    sg.Parent         = parentGui

    -- ── panel (สูงขึ้นเพื่อใส่ช่องชื่อไฟล์ + toggle) ──
    local W, H = 320, 330
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

    -- ── Title bar ──
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

    -- ── status ──
    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size                   = UDim2.new(1, -20, 0, 26)
    statusLbl.Position               = UDim2.new(0, 10, 0, 46)
    statusLbl.BackgroundTransparency = 1
    statusLbl.TextColor3             = Color3.fromRGB(160, 170, 200)
    statusLbl.Font                   = Enum.Font.Gotham
    statusLbl.TextSize               = 13
    statusLbl.TextXAlignment         = Enum.TextXAlignment.Center
    statusLbl.TextWrapped            = true
    statusLbl.Text                   = "ตั้งค่าแล้วกด Dump"
    statusLbl.Parent                 = panel

    -- ── ป้ายกำกับ: ชื่อไฟล์ ──
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size                   = UDim2.new(1, -30, 0, 18)
    nameLabel.Position               = UDim2.new(0, 15, 0, 78)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3             = Color3.fromRGB(140, 150, 180)
    nameLabel.Font                   = Enum.Font.GothamMedium
    nameLabel.TextSize               = 12
    nameLabel.TextXAlignment         = Enum.TextXAlignment.Left
    nameLabel.Text                   = "ชื่อไฟล์ (เว้นว่าง = ใช้ชื่อ map)"
    nameLabel.Parent                 = panel

    -- ── TextBox ชื่อไฟล์ ──
    local nameBox = Instance.new("TextBox")
    nameBox.Size             = UDim2.new(1, -30, 0, 34)
    nameBox.Position         = UDim2.new(0, 15, 0, 98)
    nameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 44)
    nameBox.BorderSizePixel  = 0
    nameBox.TextColor3       = Color3.fromRGB(230, 235, 255)
    nameBox.PlaceholderText  = "(อัตโนมัติจากชื่อ map)"
    nameBox.PlaceholderColor3 = Color3.fromRGB(90, 100, 130)
    nameBox.Font             = Enum.Font.Gotham
    nameBox.TextSize         = 13
    nameBox.Text             = CONFIG.DefaultFileName
    nameBox.ClearTextOnFocus = false
    nameBox.TextXAlignment   = Enum.TextXAlignment.Left
    nameBox.Parent           = panel

    local nameBoxCorner = Instance.new("UICorner")
    nameBoxCorner.CornerRadius = UDim.new(0, 8)
    nameBoxCorner.Parent = nameBox

    local nameBoxPad = Instance.new("UIPadding")
    nameBoxPad.PaddingLeft   = UDim.new(0, 8)
    nameBoxPad.PaddingRight  = UDim.new(0, 8)
    nameBoxPad.Parent = nameBox

    -- ── ป้ายกำกับ: รูปแบบ ──
    local fmtLabel = Instance.new("TextLabel")
    fmtLabel.Size                   = UDim2.new(1, -30, 0, 18)
    fmtLabel.Position               = UDim2.new(0, 15, 0, 142)
    fmtLabel.BackgroundTransparency = 1
    fmtLabel.TextColor3             = Color3.fromRGB(140, 150, 180)
    fmtLabel.Font                   = Enum.Font.GothamMedium
    fmtLabel.TextSize               = 12
    fmtLabel.TextXAlignment         = Enum.TextXAlignment.Left
    fmtLabel.Text                   = "รูปแบบไฟล์"
    fmtLabel.Parent                 = panel

    -- ── format selector (JSON / TXT) ──
    local fmtHolder = Instance.new("Frame")
    fmtHolder.Size             = UDim2.new(1, -30, 0, 38)
    fmtHolder.Position         = UDim2.new(0, 15, 0, 162)
    fmtHolder.BackgroundColor3 = Color3.fromRGB(30, 30, 44)
    fmtHolder.BorderSizePixel  = 0
    fmtHolder.Parent           = panel

    local fmtHolderCorner = Instance.new("UICorner")
    fmtHolderCorner.CornerRadius = UDim.new(0, 8)
    fmtHolderCorner.Parent = fmtHolder

    local fmtPadding = Instance.new("UIPadding")
    fmtPadding.PaddingTop    = UDim.new(0, 4)
    fmtPadding.PaddingBottom = UDim.new(0, 4)
    fmtPadding.PaddingLeft   = UDim.new(0, 4)
    fmtPadding.PaddingRight  = UDim.new(0, 4)
    fmtPadding.Parent = fmtHolder

    local fmtLayout = Instance.new("UIListLayout")
    fmtLayout.FillDirection     = Enum.FillDirection.Horizontal
    fmtLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    fmtLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
    fmtLayout.Padding           = UDim.new(0, 4)
    fmtLayout.Parent = fmtHolder

    local currentFormat = CONFIG.DefaultFormat

    local function makeFormatButton(text, value)
        local b = Instance.new("TextButton")
        b.Size             = UDim2.new(0, 140, 1, 0)
        b.BackgroundColor3 = (value == currentFormat)
            and Color3.fromRGB(40, 110, 255)
            or Color3.fromRGB(45, 45, 60)
        b.TextColor3       = Color3.fromRGB(255, 255, 255)
        b.Font             = Enum.Font.GothamBold
        b.TextSize         = 13
        b.Text             = text
        b.AutoButtonColor  = false
        b.Parent           = fmtHolder

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = b

        b.MouseButton1Click:Connect(function()
            currentFormat = value
            for _, sib in ipairs(fmtHolder:GetChildren()) do
                if sib:IsA("TextButton") then
                    sib.BackgroundColor3 = (sib == b)
                        and Color3.fromRGB(40, 110, 255)
                        or Color3.fromRGB(45, 45, 60)
                end
            end
        end)

        return b
    end

    makeFormatButton("JSON", "json")
    makeFormatButton("TXT",  "txt")

    -- ── progress bar ──
    local barBg = Instance.new("Frame")
    barBg.Size             = UDim2.new(1, -30, 0, 10)
    barBg.Position         = UDim2.new(0, 15, 0, 212)
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

    -- ── ปุ่ม Dump ──
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1, -30, 0, 44)
    btn.Position         = UDim2.new(0, 15, 0, 234)
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
        if btn.Active then
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(60, 140, 255)
            }):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if btn.Active then
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(40, 110, 255)
            }):Play()
        end
    end)

    -- ── info ──
    local infoLbl = Instance.new("TextLabel")
    infoLbl.Size                   = UDim2.new(1, -20, 0, 22)
    infoLbl.Position               = UDim2.new(0, 10, 0, 284)
    infoLbl.BackgroundTransparency = 1
    infoLbl.TextColor3             = Color3.fromRGB(90, 100, 130)
    infoLbl.Font                   = Enum.Font.Gotham
    infoLbl.TextSize               = 12
    infoLbl.TextXAlignment         = Enum.TextXAlignment.Center
    infoLbl.TextWrapped            = true
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

    -- ── close ──
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
            if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                TweenService:Create(child, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
            end
        end

        task.delay(0.6, function() sg:Destroy() end)
    end

    -- ── Dump ──
    local busy = false
    btn.MouseButton1Click:Connect(function()
        if busy then return end
        busy = true
        btn.Active = false

        local chosenFormat = currentFormat
        local typedName    = nameBox.Text

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
            local ok, a, b, fname = pcall(runDump, onProgress, chosenFormat, typedName)
            if ok then
                barFill.BackgroundColor3 = Color3.fromRGB(40, 200, 110)
                TweenService:Create(barFill, TweenInfo.new(0.3), {
                    Size = UDim2.new(1, 0, 1, 0)
                }):Play()

                statusLbl.Text       = "✅  dump สำเร็จ!"
                statusLbl.TextColor3 = Color3.fromRGB(100, 230, 150)
                infoLbl.Text         = string.format("%.2f วินาที • %s\n→ %s",
                    a, (b >= 1048576 and string.format("%.2f MB", b/1048576)
                        or string.format("%.1f KB", b/1024)),
                    tostring(fname))
                btn.Text             = "✅  เสร็จแล้ว"
                btn.BackgroundColor3 = Color3.fromRGB(30, 170, 80)

                warn(string.format("[MapDumper] ✅ บันทึกสำเร็จ → %s (%.2f วินาที, %.1f KB)",
                    tostring(fname), a, b/1024))

                task.wait(2)
                closePanel()
            else
                barFill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
                statusLbl.Text       = "❌  " .. tostring(a):sub(1, 70)
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

local okGui, guiErr = pcall(makeGui)
if not okGui then
    warn("[MapDumper] makeGui error: " .. tostring(guiErr))
end
