--!nolint
--!nocheck

-- AxionHub Dump: Complete Edition (Localized & Remote Spy)

local __ok, __err = pcall(function()
local Players = game:GetService("Players")
local LP = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- Clean up only this script's previous UI.
pcall(function()
    local roots = {}
    if LP:FindFirstChildOfClass("PlayerGui") then table.insert(roots, LP:FindFirstChildOfClass("PlayerGui")) end
    pcall(function() if gethui then table.insert(roots, gethui()) end end)
    for _, root in ipairs(roots) do
        for _, item in ipairs(root:GetChildren()) do
            if item.Name == "AxionHub_DumpToolkit" or item.Name == "AxionHub_Dump_OpenButton" then
                pcall(function() item:Destroy() end)
            end
        end
    end
end)

-- AxionHub-style UI adapter.
-- It intentionally implements the small WindUI-compatible surface used below,
-- so the existing tabs and callbacks can use the AxionHub visual style without
-- downloading a third-party UI library at runtime.
local AxionUI = {}
local AxionPalette = {
    bgTop = Color3.fromRGB(26, 12, 48),
    bgBottom = Color3.fromRGB(4, 2, 9),
    panelTop = Color3.fromRGB(44, 20, 82),
    panelBottom = Color3.fromRGB(14, 6, 28),
    sidebarTop = Color3.fromRGB(14, 6, 26),
    sidebarBottom = Color3.fromRGB(2, 1, 5),
    text = Color3.fromRGB(245, 246, 255),
    muted = Color3.fromRGB(153, 158, 184),
    accentBlue = Color3.fromRGB(84, 38, 232),
    accentPink = Color3.fromRGB(172, 44, 248),
    success = Color3.fromRGB(94, 224, 164),
    danger = Color3.fromRGB(255, 103, 126),
    track = Color3.fromRGB(26, 14, 44),
}
local AxionGui, AxionWindow, AxionContent, AxionSidebar, AxionTabButtons
local AxionTabs = {}
local AxionSelectedTab
local AxionToastToken = 0
local AxionOpenButton

local function axionCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = parent
    return c
end

local function axionGradient(parent, rotation, first, second)
    local g = Instance.new("UIGradient")
    g.Rotation = rotation or 0
    g.Color = ColorSequence.new(first or AxionPalette.accentBlue, second or AxionPalette.accentPink)
    g.Parent = parent
    return g
end

local function axionStroke(parent, transparency)
    local s = Instance.new("UIStroke")
    s.Thickness = 1
    s.Transparency = transparency or 0.45
    s.Color = AxionPalette.accentBlue
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    axionGradient(s, 0, AxionPalette.accentBlue, AxionPalette.accentPink)
    return s
end

local function axionLabel(parent, text, size, position, textSize, color, font, xAlign)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.Size = size
    label.Position = position
    label.Text = tostring(text or "")
    label.TextSize = textSize or 12
    label.TextColor3 = color or AxionPalette.text
    label.Font = font or Enum.Font.Gotham
    label.TextXAlignment = xAlign or Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextWrapped = true
    label.ZIndex = (parent.ZIndex or 1) + 1
    label.Parent = parent
    return label
end

local function axionParent()
    local ok, parent = pcall(function()
        if gethui then return gethui() end
        return LP:WaitForChild("PlayerGui")
    end)
    if ok and parent then return parent end
    return LP:WaitForChild("PlayerGui")
end

local function axionMakeDraggable(handle, target)
    local UIS = game:GetService("UserInputService")
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local function axionNotify(title, content, icon, duration)
    if not AxionGui or not AxionGui.Parent then
        warn(("[AxionHub Dump] %s: %s"):format(tostring(title), tostring(content)))
        return
    end
    AxionToastToken += 1
    local token = AxionToastToken
    local old = AxionGui:FindFirstChild("AxionToast")
    if old then old:Destroy() end

    local toast = Instance.new("Frame")
    toast.Name = "AxionToast"
    toast.AnchorPoint = Vector2.new(1, 0)
    toast.Position = UDim2.new(1, -16, 0, 16)
    toast.Size = UDim2.new(0, 270, 0, 66)
    toast.BackgroundColor3 = AxionPalette.panelTop
    toast.BorderSizePixel = 0
    toast.ZIndex = 80
    toast.Parent = AxionGui
    axionCorner(toast, 12)
    axionStroke(toast, 0.2)

    local stripe = Instance.new("Frame")
    stripe.Size = UDim2.new(0, 4, 1, -16)
    stripe.Position = UDim2.new(0, 7, 0, 8)
    stripe.BackgroundColor3 = AxionPalette.accentBlue
    stripe.BorderSizePixel = 0
    stripe.ZIndex = 81
    stripe.Parent = toast
    axionCorner(stripe, 99)
    axionGradient(stripe, 90)

    axionLabel(toast, title or "AxionHub Dump", UDim2.new(1, -30, 0, 22), UDim2.new(0, 20, 0, 7), 12, AxionPalette.text, Enum.Font.GothamBold)
    local desc = axionLabel(toast, content or "", UDim2.new(1, -30, 0, 30), UDim2.new(0, 20, 0, 29), 10, AxionPalette.muted)
    desc.TextYAlignment = Enum.TextYAlignment.Top

    task.delay(tonumber(duration) or 3, function()
        if token == AxionToastToken and toast.Parent then toast:Destroy() end
    end)
end

function AxionUI:AddTheme(_theme)
    -- The palette above is the built-in AxionHub-style theme.
end

function AxionUI:Notify(options)
    options = options or {}
    axionNotify(options.Title or "AxionHub Dump", options.Content or "", options.Icon, options.Duration)
end

function AxionUI:CreateWindow(options)
    options = options or {}
    local playerGui = axionParent()

    AxionGui = Instance.new("ScreenGui")
    AxionGui.Name = "AxionHub_DumpToolkit"
    AxionGui.ResetOnSpawn = false
    AxionGui.IgnoreGuiInset = true
    AxionGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    AxionGui.DisplayOrder = 999
    AxionGui.Parent = playerGui

    AxionWindow = Instance.new("Frame")
    AxionWindow.Name = "MainWindow"
    AxionWindow.Size = options.Size or UDim2.fromOffset(900, 540)
    AxionWindow.AnchorPoint = Vector2.new(0.5, 0.5)
    AxionWindow.Position = UDim2.new(0.5, 0, 0.5, 0)
    AxionWindow.BackgroundColor3 = AxionPalette.bgBottom
    AxionWindow.BackgroundTransparency = 0.04
    AxionWindow.BorderSizePixel = 0
    AxionWindow.ClipsDescendants = true
    AxionWindow.ZIndex = 2
    AxionWindow.Parent = AxionGui
    axionCorner(AxionWindow, 16)
    axionGradient(AxionWindow, 115, AxionPalette.bgTop, AxionPalette.bgBottom)
    axionStroke(AxionWindow, 0.18)

    local scale = Instance.new("UIScale")
    scale.Parent = AxionWindow
    local function updateScale()
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
        scale.Scale = math.clamp(math.min((viewport.X * 0.94) / 900, (viewport.Y * 0.9) / 540, 1), 0.48, 1)
    end
    updateScale()
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    end

    local topbar = Instance.new("Frame")
    topbar.Name = "Topbar"
    topbar.Size = UDim2.new(1, 0, 0, 54)
    topbar.BackgroundColor3 = AxionPalette.panelTop
    topbar.BackgroundTransparency = 0.12
    topbar.BorderSizePixel = 0
    topbar.ZIndex = 4
    topbar.Parent = AxionWindow
    axionGradient(topbar, 0, AxionPalette.panelTop, AxionPalette.bgTop)
    axionMakeDraggable(topbar, AxionWindow)

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(1, 0, 0, 2)
    accent.BackgroundColor3 = AxionPalette.accentBlue
    accent.BorderSizePixel = 0
    accent.ZIndex = 5
    accent.Parent = topbar
    axionGradient(accent, 0)

    local logo = Instance.new("ImageLabel")
    logo.BackgroundTransparency = 1
    logo.Size = UDim2.fromOffset(30, 30)
    logo.Position = UDim2.new(0, 15, 0.5, -15)
    logo.Image = tostring(options.Icon or "rbxassetid://10709819149")
    logo.ScaleType = Enum.ScaleType.Fit
    logo.ZIndex = 6
    logo.Parent = topbar

    axionLabel(topbar, options.Title or "AxionHub Dump", UDim2.new(0, 250, 0, 20), UDim2.new(0, 54, 0, 8), 14, AxionPalette.text, Enum.Font.GothamBold)
    axionLabel(topbar, options.Author or "AxionHub UI", UDim2.new(0, 250, 0, 16), UDim2.new(0, 54, 0, 28), 10, AxionPalette.muted, Enum.Font.Gotham)

    local minimize = Instance.new("TextButton")
    minimize.Name = "Minimize"
    minimize.Size = UDim2.fromOffset(30, 30)
    minimize.Position = UDim2.new(1, -42, 0, 12)
    minimize.BackgroundColor3 = AxionPalette.track
    minimize.Text = "—"
    minimize.TextSize = 16
    minimize.TextColor3 = AxionPalette.text
    minimize.Font = Enum.Font.GothamBold
    minimize.AutoButtonColor = true
    minimize.ZIndex = 6
    minimize.Parent = topbar
    axionCorner(minimize, 9)

    AxionSidebar = Instance.new("Frame")
    AxionSidebar.Name = "Sidebar"
    AxionSidebar.Size = UDim2.new(0, 220, 1, -54)
    AxionSidebar.Position = UDim2.new(0, 0, 0, 54)
    AxionSidebar.BackgroundColor3 = AxionPalette.sidebarBottom
    AxionSidebar.BorderSizePixel = 0
    AxionSidebar.ZIndex = 3
    AxionSidebar.Parent = AxionWindow
    axionGradient(AxionSidebar, 90, AxionPalette.sidebarTop, AxionPalette.sidebarBottom)

    axionLabel(AxionSidebar, "AxionHub", UDim2.new(1, -24, 0, 22), UDim2.new(0, 14, 0, 42), 13, AxionPalette.text, Enum.Font.GothamBold)
    axionLabel(AxionSidebar, "Dump Toolkit", UDim2.new(1, -24, 0, 18), UDim2.new(0, 14, 0, 62), 10, AxionPalette.muted, Enum.Font.Gotham)

    AxionContent = Instance.new("Frame")
    AxionContent.Name = "Content"
    AxionContent.Size = UDim2.new(1, -220, 1, -54)
    AxionContent.Position = UDim2.new(0, 220, 0, 54)
    AxionContent.BackgroundTransparency = 1
    AxionContent.BorderSizePixel = 0
    AxionContent.ZIndex = 3
    AxionContent.Parent = AxionWindow

    AxionTabButtons = {}
    AxionTabs = {}
    AxionSelectedTab = nil

    local function selectTab(tab)
        if not tab or not tab.page then return end
        AxionSelectedTab = tab
        for _, candidate in ipairs(AxionTabs) do
            candidate.page.Visible = candidate == tab
            candidate.button.BackgroundTransparency = candidate == tab and 0.08 or 1
            candidate.button.TextColor3 = candidate == tab and AxionPalette.text or AxionPalette.muted
            local bar = candidate.button:FindFirstChild("ActiveBar")
            if bar then bar.Visible = candidate == tab end
        end
    end

    local Window = {}
    function Window:EditOpenButton(openOptions)
        openOptions = openOptions or {}
        if AxionOpenButton then pcall(function() AxionOpenButton:Destroy() end) end
        AxionOpenButton = Instance.new("TextButton")
        AxionOpenButton.Name = "AxionHub_Dump_OpenButton"
        AxionOpenButton.Size = UDim2.fromOffset(54, 54)
        AxionOpenButton.Position = UDim2.new(0, 20, 0.35, 0)
        AxionOpenButton.BackgroundColor3 = AxionPalette.panelTop
        AxionOpenButton.Text = "AX"
        AxionOpenButton.TextColor3 = AxionPalette.text
        AxionOpenButton.TextSize = 13
        AxionOpenButton.Font = Enum.Font.GothamBold
        AxionOpenButton.AutoButtonColor = true
        AxionOpenButton.Active = true
        AxionOpenButton.Draggable = true
        AxionOpenButton.ZIndex = 100
        AxionOpenButton.Parent = playerGui
        axionCorner(AxionOpenButton, 14)
        axionStroke(AxionOpenButton, 0.15)
        AxionOpenButton.MouseButton1Click:Connect(function()
            AxionWindow.Visible = not AxionWindow.Visible
        end)
    end
    function Window:Tag(_tag) end
    function Window:SetBackgroundTransparency(value)
        AxionWindow.BackgroundTransparency = tonumber(value) or 0
    end
    function Window:SelectTab(tab)
        selectTab(tab)
    end
    function Window:Tab(tabOptions)
        tabOptions = tabOptions or {}
        local tab = { title = tabOptions.Title or "Tab", sections = {} }
        local index = #AxionTabs + 1
        local button = Instance.new("TextButton")
        button.Name = "Tab_" .. tostring(index)
        button.Size = UDim2.new(1, -20, 0, 48)
        button.Position = UDim2.new(0, 10, 0, 96 + (index - 1) * 58)
        button.BackgroundColor3 = AxionPalette.panelTop
        button.BackgroundTransparency = 1
        button.BorderSizePixel = 0
        button.Text = "   " .. tostring(tab.title)
        button.TextSize = 12
        button.TextColor3 = AxionPalette.muted
        button.TextXAlignment = Enum.TextXAlignment.Left
        button.Font = Enum.Font.GothamMedium
        button.AutoButtonColor = false
        button.ZIndex = 5
        button.Parent = AxionSidebar
        axionCorner(button, 10)

        local activeBar = Instance.new("Frame")
        activeBar.Name = "ActiveBar"
        activeBar.Size = UDim2.new(0, 3, 1, -12)
        activeBar.Position = UDim2.new(0, 0, 0, 6)
        activeBar.BackgroundColor3 = AxionPalette.accentBlue
        activeBar.BorderSizePixel = 0
        activeBar.Visible = false
        activeBar.ZIndex = 6
        activeBar.Parent = button
        axionCorner(activeBar, 99)
        axionGradient(activeBar, 90)

        local page = Instance.new("ScrollingFrame")
        page.Name = "Page_" .. tostring(index)
        page.Size = UDim2.new(1, -22, 1, -18)
        page.Position = UDim2.new(0, 11, 0, 9)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = AxionPalette.accentBlue
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.Visible = false
        page.ZIndex = 4
        page.Parent = AxionContent
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 10)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = page
        local padding = Instance.new("UIPadding")
        padding.PaddingBottom = UDim.new(0, 12)
        padding.PaddingRight = UDim.new(0, 3)
        padding.Parent = page

        tab.button, tab.page = button, page
        table.insert(AxionTabs, tab)
        button.MouseButton1Click:Connect(function() selectTab(tab) end)
        if not AxionSelectedTab then selectTab(tab) end

        function tab:Section(sectionOptions)
            sectionOptions = sectionOptions or {}
            local section = {}
            local card = Instance.new("Frame")
            card.Name = "Section"
            card.Size = UDim2.new(1, -4, 0, 52)
            card.AutomaticSize = Enum.AutomaticSize.Y
            card.BackgroundColor3 = AxionPalette.panelTop
            card.BackgroundTransparency = 0.12
            card.BorderSizePixel = 0
            card.ZIndex = 5
            card.Parent = page
            axionCorner(card, 12)
            axionStroke(card, 0.68)
            local cardLayout = Instance.new("UIListLayout")
            cardLayout.Padding = UDim.new(0, 7)
            cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
            cardLayout.Parent = card
            local cardPadding = Instance.new("UIPadding")
            cardPadding.PaddingTop = UDim.new(0, 12)
            cardPadding.PaddingBottom = UDim.new(0, 12)
            cardPadding.PaddingLeft = UDim.new(0, 12)
            cardPadding.PaddingRight = UDim.new(0, 12)
            cardPadding.Parent = card
            local heading = axionLabel(card, sectionOptions.Title or "Section", UDim2.new(1, 0, 0, 18), UDim2.new(), 12, AxionPalette.text, Enum.Font.GothamBold)
            heading.LayoutOrder = 1
            if sectionOptions.Desc and sectionOptions.Desc ~= "" then
                local sub = axionLabel(card, sectionOptions.Desc, UDim2.new(1, 0, 0, 30), UDim2.new(), 10, AxionPalette.muted, Enum.Font.Gotham)
                sub.TextYAlignment = Enum.TextYAlignment.Top
                sub.LayoutOrder = 2
            end
            local contentLayoutOrder = 3
            local function makeRow(height)
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, height)
                row.BackgroundTransparency = 1
                row.BorderSizePixel = 0
                row.ZIndex = 6
                row.LayoutOrder = contentLayoutOrder
                contentLayoutOrder += 1
                row.Parent = card
                return row
            end
            function section:Paragraph(paragraphOptions)
                paragraphOptions = paragraphOptions or {}
                local row = makeRow(45)
                local title = axionLabel(row, paragraphOptions.Title or "Status", UDim2.new(1, 0, 0, 16), UDim2.new(), 10, AxionPalette.accentPink, Enum.Font.GothamBold)
                local desc = axionLabel(row, paragraphOptions.Desc or "", UDim2.new(1, 0, 0, 27), UDim2.new(0, 0, 0, 16), 10, AxionPalette.text, Enum.Font.Gotham)
                desc.TextYAlignment = Enum.TextYAlignment.Top
                local object = {}
                function object:SetDesc(value) desc.Text = tostring(value or "") end
                function object:SetTitle(value) title.Text = tostring(value or "") end
                return object
            end
            function section:Button(buttonOptions)
                buttonOptions = buttonOptions or {}
                local row = makeRow(buttonOptions.Desc and buttonOptions.Desc ~= "" and 62 or 42)
                local button = Instance.new("TextButton")
                button.Size = UDim2.new(1, 0, 0, 38)
                button.Position = UDim2.new(0, 0, 0, buttonOptions.Desc and buttonOptions.Desc ~= "" and 22 or 2)
                button.BackgroundColor3 = AxionPalette.track
                button.BackgroundTransparency = 0.15
                button.BorderSizePixel = 0
                button.Text = "   " .. tostring(buttonOptions.Title or "Action") .. "     ›"
                button.TextSize = 12
                button.TextColor3 = AxionPalette.text
                button.TextXAlignment = Enum.TextXAlignment.Left
                button.Font = Enum.Font.GothamMedium
                button.AutoButtonColor = true
                button.ZIndex = 7
                button.Parent = row
                axionCorner(button, 9)
                local stroke = axionStroke(button, 0.72)
                if buttonOptions.Desc and buttonOptions.Desc ~= "" then
                    local d = axionLabel(row, buttonOptions.Desc, UDim2.new(1, 0, 0, 16), UDim2.new(), 9, AxionPalette.muted, Enum.Font.Gotham)
                    d.ZIndex = 7
                end
                button.MouseButton1Click:Connect(function()
                    if buttonOptions.Callback then
                        local ok, err = pcall(buttonOptions.Callback)
                        if not ok then warn("[AxionHub Dump] Button callback failed: " .. tostring(err)) end
                    end
                end)
                button.MouseEnter:Connect(function() stroke.Transparency = 0.25 end)
                button.MouseLeave:Connect(function() stroke.Transparency = 0.72 end)
                return button
            end
            function section:Toggle(toggleOptions)
                toggleOptions = toggleOptions or {}
                local row = makeRow(toggleOptions.Desc and toggleOptions.Desc ~= "" and 58 or 38)
                local label = axionLabel(row, toggleOptions.Title or "Toggle", UDim2.new(1, -70, 0, 18), UDim2.new(), 11, AxionPalette.text, Enum.Font.GothamMedium)
                if toggleOptions.Desc and toggleOptions.Desc ~= "" then
                    local d = axionLabel(row, toggleOptions.Desc, UDim2.new(1, -70, 0, 28), UDim2.new(0, 0, 0, 19), 9, AxionPalette.muted, Enum.Font.Gotham)
                    d.TextYAlignment = Enum.TextYAlignment.Top
                end
                local toggle = Instance.new("TextButton")
                toggle.Size = UDim2.fromOffset(44, 24)
                toggle.Position = UDim2.new(1, -44, 0, 4)
                toggle.BackgroundColor3 = AxionPalette.track
                toggle.BorderSizePixel = 0
                toggle.Text = ""
                toggle.AutoButtonColor = false
                toggle.ZIndex = 8
                toggle.Parent = row
                axionCorner(toggle, 99)
                local fill = Instance.new("Frame")
                fill.Size = UDim2.new(1, 0, 1, 0)
                fill.BackgroundColor3 = AxionPalette.accentBlue
                fill.BackgroundTransparency = 1
                fill.BorderSizePixel = 0
                fill.ZIndex = 9
                fill.Parent = toggle
                axionCorner(fill, 99)
                axionGradient(fill, 0)
                local knob = Instance.new("Frame")
                knob.Size = UDim2.fromOffset(18, 18)
                knob.Position = UDim2.new(0, 3, 0.5, -9)
                knob.BackgroundColor3 = AxionPalette.text
                knob.BorderSizePixel = 0
                knob.ZIndex = 10
                knob.Parent = toggle
                axionCorner(knob, 99)
                local value = toggleOptions.Value == true
                local function render()
                    fill.BackgroundTransparency = value and 0 or 1
                    knob.Position = value and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
                end
                local function setValue(nextValue, fire)
                    value = nextValue == true
                    render()
                    if fire and toggleOptions.Callback then
                        local ok, err = pcall(toggleOptions.Callback, value)
                        if not ok then warn("[AxionHub Dump] Toggle callback failed: " .. tostring(err)) end
                    end
                end
                render()
                toggle.MouseButton1Click:Connect(function() setValue(not value, true) end)
                local object = {}
                function object:SetValue(nextValue) setValue(nextValue, false) end
                function object:GetValue() return value end
                return object
            end
            function section:Dropdown(dropOptions)
                dropOptions = dropOptions or {}
                local row = makeRow(60)
                axionLabel(row, dropOptions.Title or "Select", UDim2.new(1, 0, 0, 17), UDim2.new(), 11, AxionPalette.text, Enum.Font.GothamMedium)
                if dropOptions.Desc and dropOptions.Desc ~= "" then
                    local d = axionLabel(row, dropOptions.Desc, UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 17), 9, AxionPalette.muted)
                    d.TextYAlignment = Enum.TextYAlignment.Top
                end
                local button = Instance.new("TextButton")
                button.Size = UDim2.new(1, 0, 0, 28)
                button.Position = UDim2.new(0, 0, 0, 32)
                button.BackgroundColor3 = AxionPalette.track
                button.BorderSizePixel = 0
                button.TextSize = 10
                button.TextColor3 = AxionPalette.text
                button.TextXAlignment = Enum.TextXAlignment.Left
                button.Font = Enum.Font.Gotham
                button.AutoButtonColor = true
                button.ZIndex = 8
                button.Parent = row
                axionCorner(button, 8)

                local values = dropOptions.Values or {}
                local selected = dropOptions.Value
                local menu = Instance.new("ScrollingFrame")
                menu.Name = "OptionsMenu"
                menu.Size = UDim2.new(1, 0, 0, 145)
                menu.Position = UDim2.new(0, 0, 0, 63)
                menu.BackgroundColor3 = AxionPalette.panelBottom
                menu.BorderSizePixel = 0
                menu.ScrollBarThickness = 3
                menu.ScrollBarImageColor3 = AxionPalette.accentPink
                menu.CanvasSize = UDim2.new(0, 0, 0, 0)
                menu.AutomaticCanvasSize = Enum.AutomaticSize.Y
                menu.Visible = false
                menu.ZIndex = 25
                menu.Parent = row
                axionCorner(menu, 8)
                axionStroke(menu, 0.25)
                local menuLayout = Instance.new("UIListLayout")
                menuLayout.Padding = UDim.new(0, 2)
                menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
                menuLayout.Parent = menu
                local menuPadding = Instance.new("UIPadding")
                menuPadding.PaddingTop = UDim.new(0, 4)
                menuPadding.PaddingBottom = UDim.new(0, 4)
                menuPadding.PaddingLeft = UDim.new(0, 4)
                menuPadding.PaddingRight = UDim.new(0, 4)
                menuPadding.Parent = menu

                local function render()
                    button.Text = "  " .. tostring(selected or "Select an option") .. (menu.Visible and "    ▴" or "    ▾")
                end
                local function choose(value)
                    selected = value
                    menu.Visible = false
                    render()
                    if dropOptions.Callback then
                        local ok, err = pcall(dropOptions.Callback, selected)
                        if not ok then warn("[AxionHub Dump] Dropdown callback failed: " .. tostring(err)) end
                    end
                end
                for i, value in ipairs(values) do
                    local option = Instance.new("TextButton")
                    option.Name = "Option_" .. tostring(i)
                    option.Size = UDim2.new(1, -2, 0, 25)
                    option.BackgroundColor3 = AxionPalette.panelTop
                    option.BackgroundTransparency = 0.2
                    option.BorderSizePixel = 0
                    option.Text = "  " .. tostring(value)
                    option.TextSize = 10
                    option.TextColor3 = AxionPalette.text
                    option.TextXAlignment = Enum.TextXAlignment.Left
                    option.Font = Enum.Font.Gotham
                    option.AutoButtonColor = true
                    option.LayoutOrder = i
                    option.ZIndex = 26
                    option.Parent = menu
                    axionCorner(option, 6)
                    option.MouseButton1Click:Connect(function() choose(value) end)
                end
                render()
                button.MouseButton1Click:Connect(function()
                    menu.Visible = not menu.Visible
                    render()
                end)
                local object = {}
                function object:SetValue(value)
                    selected = value
                    menu.Visible = false
                    render()
                    if dropOptions.Callback then dropOptions.Callback(value) end
                end
                function object:GetValue() return selected end
                return object
            end
            return section
        end
        return tab
    end
    return Window
end

local WindUI = AxionUI

-- Localization System (รองรับ TH / EN)
local currentLang = _G.AxionHubLanguage or "EN"
local Loc = {
    EN = {
        Title = "AxionHub Dump",
        Author = "Dump Toolkit",
        Tag = "Ultimate Dumper",
        Tab1 = "Script Toolkit",
        Tab2 = "Remote Dumper",
        Tab3 = "Dump Explorer",
        Ready = "Ready",
        ToolkitDesc = "Complete indexing, boilerplate, and full game dump in one click",
        DecompileMod = "Decompile ModuleScripts Source",
        DecompileDesc = "Extract Lua source code for all indexed modules (Slower)",
        ActionOut = "Action & Output",
        ActionDesc = "Generates a fully formed .txt scripting workspace",
        RunMaster = "Execute Master Dump (.txt)",
        RunMasterDesc = "Indexes all services, remotes, configs, and saves as a single .txt file",
        RemoteSecTitle = "All Remote Scanner",
        RemoteSecDesc = "Extract all RemoteEvents and RemoteFunctions across the game",
        DumpRemotesBtn = "Dump All Remotes (.txt)",
        DumpRemotesDesc = "Search and dump all Remotes in the game to a single .txt file",
        SpyTitle = "Runtime Remote Spy (Argument Logger)",
        SpyDesc = "Capture live remote calls and arguments while playing",
        EnableSpy = "Enable Remote Spy Hook",
        EnableSpyDesc = "Start capturing remote calls and arguments in real-time",
        SaveSpyBtn = "Save Spied Logs (.txt)",
        SaveSpyDesc = "Save all captured remote calls and arguments to workspace",
        ClearSpyBtn = "Clear Captured Logs",
        ClearSpyDesc = "Reset captured spy data",
        ConfigSec = "Configuration",
        ConfigDesc = "Select a target service to dump",
        TargetDrop = "Target Service",
        TargetDesc = "Choose a service or select Full Dump for the whole game",
        DecompileExp = "Decompile ModuleScripts",
        DecompileExpDesc = "Decompile module source code (takes longer)",
        ExecSec = "Execution & Status",
        ExecDesc = "Execute process and monitor real-time output",
        StartDumpBtn = "Start Dump (.txt)",
        StartDumpDesc = "Scan service hierarchy tree and save as .txt to workspace",
    },
    TH = {
        Title = "AxionHub Dump",
        Author = "โดย 777",
        Tag = "ระบบดึงข้อมูลขั้นสุดยอด",
        Tab1 = "ชุดเครื่องมือสคริปต์",
        Tab2 = "ตัวดึงรีโมท (Remote)",
        Tab3 = "สำรวจโครงสร้างข้อมูล",
        Ready = "พร้อมใช้งาน",
        ToolkitDesc = "สแกนข้อมูล สร้างโค้ดโครงสร้าง และดึงข้อมูลเกมทั้งหมดได้ในคลิกเดียว",
        DecompileMod = "ถอดรหัสซอร์สโค้ด ModuleScripts",
        DecompileDesc = "ดึงโค้ด Lua ภายในโมดูลทั้งหมด (ใช้เวลาช้าลงเล็กน้อย)",
        ActionOut = "การทำงานและผลลัพธ์",
        ActionDesc = "สร้างไฟล์พื้นที่ทำงานสคริปต์ในรูปแบบ .txt สมบูรณ์แบบ",
        RunMaster = "รันมาสเตอร์ดัมพ์ (.txt)",
        RunMasterDesc = "ดัชนีบริการ รีโมท โมดูล และบันทึกเป็นไฟล์ .txt เดียว",
        RemoteSecTitle = "สแกนรีโมททั้งหมด",
        RemoteSecDesc = "ดึงข้อมูล RemoteEvents และ RemoteFunctions ทั้งหมดในเกม",
        DumpRemotesBtn = "ดัมพ์รีโมททั้งหมด (.txt)",
        DumpRemotesDesc = "ค้นหาและบันทึกรีโมททั้งหมดลงในไฟล์ .txt",
        SpyTitle = "สปายรีโมทขณะเล่น (บันทึก Arguments)",
        SpyDesc = "ดักจับการเรียกใช้รีโมทและค่าพารามิเตอร์แบบเรียลไทม์",
        EnableSpy = "เปิดใช้งานตัวดักจับรีโมท",
        EnableSpyDesc = "เริ่มบันทึกการเรียกใช้รีโมทและค่า Arguments ทันที",
        SaveSpyBtn = "บันทึกประวัติสปาย (.txt)",
        SaveSpyDesc = "บันทึกข้อมูลการเรียกรีโมททั้งหมดลงในโฟลเดอร์ workspace",
        ClearSpyBtn = "ล้างประวัติที่บันทึก",
        ClearSpyDesc = "รีเซ็ตข้อมูลสปายทั้งหมด",
        ConfigSec = "การตั้งค่า",
        ConfigDesc = "เลือกบริการที่ต้องการดัมพ์",
        TargetDrop = "บริการเป้าหมาย",
        TargetDesc = "เลือก Service หรือเลือกดัมพ์ทั้งหมดของเกม",
        DecompileExp = "ถอดรหัส ModuleScripts",
        DecompileExpDesc = "ดึงซอร์สโค้ดโมดูล (ใช้เวลานานขึ้น)",
        ExecSec = "การทำงานและสถานะ",
        ExecDesc = "เริ่มกระบวนการและตรวจสอบสถานะแบบเรียลไทม์",
        StartDumpBtn = "เริ่มดัมพ์โครงสร้าง (.txt)",
        StartDumpDesc = "สแกนโครงสร้าง Service และบันทึกเป็นไฟล์ .txt",
    }
}

local function L(key)
    return Loc[currentLang][key] or Loc["EN"][key] or key
end

-- AxionHub-inspired dark gradient theme.
WindUI:AddTheme({ Name = "AxionHub" })

local LOGO_ID = "rbxassetid://10709819149"

-- Create the main window through the built-in AxionHub-style adapter.
local Window = WindUI:CreateWindow({
    Title = L("Title"),
    Author = L("Author"),
    Icon = LOGO_ID,
    Theme = "AxionHub",
    Transparent = true,
    Topbar = { Height = 52, ButtonsType = "Mac" },
    Size = UDim2.fromOffset(900, 540),
})

Window:EditOpenButton({
    Title = L("Title"),
    Icon = LOGO_ID,
    Enabled = true,
    Draggable = true,
})

Window:Tag({
    Title = L("Tag"),
    Icon = "database",
    Color = Color3.fromRGB(93, 117, 255),
    Radius = 13,
})

pcall(function() Window:SetBackgroundTransparency(0.04) end)

-- Gather all game services and sort alphabetically (A-Z)
local serviceList = {}
for _, service in ipairs(game:GetChildren()) do
    pcall(function()
        if service and service.Name then
            table.insert(serviceList, service.Name)
        end
    end)
end

table.insert(serviceList, "PlayerScripts")
table.insert(serviceList, "PlayerGui")
table.insert(serviceList, "LocalPlayer Character")

table.sort(serviceList, function(a, b)
    return a:lower() < b:lower()
end)

local TARGET_OPTIONS = { "[All Services - Full Dump]" }
for _, name in ipairs(serviceList) do
    table.insert(TARGET_OPTIONS, name)
end

-- Shared Utility Functions
local function formatTree(instance, depth)
    local indent = string.rep("    ", depth)
    local branch = depth > 0 and "|-- " or ""
    return string.format("%s%s[%s] %s", indent, branch, instance.ClassName, instance.Name)
end

local function getCleanPath(inst)
    local parts = {}
    local curr = inst
    while curr and curr ~= game do
        local name = curr.Name
        if name:match("^[%a_][%w_]*$") then
            table.insert(parts, 1, "." .. name)
        else
            table.insert(parts, 1, '["' .. name:gsub('"', '\\"') .. '"]')
        end
        curr = curr.Parent
    end
    if #parts > 0 and parts[1]:sub(1, 1) == "." then
        parts[1] = parts[1]:sub(2)
    end
    local serviceName = inst:GetFullName():split(".")[1]
    return "game:GetService(\"" .. serviceName .. "\")." .. table.concat(parts, ""):gsub("^[^%.]+%.?", "")
end

local function serializeValue(val, depth)
    depth = depth or 0
    if depth > 3 then return "[Max Depth]" end
    local customType = typeof(val)
    if customType == "string" then
        return '"' .. val:gsub('"', '\\"') .. '"'
    elseif customType == "number" or customType == "boolean" then
        return tostring(val)
    elseif customType == "nil" then
        return "nil"
    elseif customType == "table" then
        local parts = {}
        local count = 0
        for k, v in pairs(val) do
            count = count + 1
            if count > 16 then table.insert(parts, "..."); break end
            table.insert(parts, tostring(k) .. " = " .. serializeValue(v, depth + 1))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif customType == "Instance" then
        return getCleanPath(val)
    elseif customType == "Vector3" then
        return string.format("Vector3(%g, %g, %g)", val.X, val.Y, val.Z)
    elseif customType == "Vector2" then
        return string.format("Vector2(%g, %g)", val.X, val.Y)
    elseif customType == "CFrame" then
        local p = val.Position
        return string.format("CFrame(%g, %g, %g)", p.X, p.Y, p.Z)
    elseif customType == "Color3" then
        return string.format("Color3(%d, %d, %d)", math.floor(val.R*255), math.floor(val.G*255), math.floor(val.B*255))
    elseif customType == "EnumItem" then
        return tostring(val)
    elseif customType == "UDim2" then
        return string.format("UDim2(%g, %g, %g, %g)", val.X.Scale, val.X.Offset, val.Y.Scale, val.Y.Offset)
    elseif customType == "UDim" then
        return string.format("UDim(%g, %g)", val.Scale, val.Offset)
    elseif customType == "Rect" then
        return string.format("Rect(%g, %g, %g, %g)", val.Min.X, val.Min.Y, val.Max.X, val.Max.Y)
    else
        return "[" .. customType .. "]"
    end
end

-- ==============================================================================
-- TAB 1: SCRIPT TOOLKIT
-- ==============================================================================
local ToolTab = Window:Tab({ Title = L("Tab1"), Icon = "file-code" })

local SettingsToolkit = {
    DecompileSource = false,
    IsRunning = false
}

local toolCfgSec = ToolTab:Section({
    Opened = true,
    Title = L("ToolkitDesc"),
    Desc = ""
})

toolCfgSec:Toggle({
    Title = L("DecompileMod"),
    Desc = L("DecompileDesc"),
    Value = false,
    Callback = function(v)
        SettingsToolkit.DecompileSource = v
    end
})

local toolActSec = ToolTab:Section({
    Opened = true,
    Title = L("ActionOut"),
    Desc = L("ActionDesc")
})

local statusParaToolkit = toolActSec:Paragraph({
    Title = "Status",
    Desc = L("Ready")
})

local function setStatusToolkit(msg)
    pcall(function() statusParaToolkit:SetDesc(tostring(msg)) end)
end

toolActSec:Button({
    Title = L("RunMaster"),
    Desc = L("RunMasterDesc"),
    Callback = function()
        if SettingsToolkit.IsRunning then return end
        SettingsToolkit.IsRunning = true
        setStatusToolkit("Starting Master Dump...")

        task.spawn(function()
            local startTime = os.clock()
            local remotesFound = {}
            local modulesFound = {}
            local promptsFound = {}
            local fullOutput = {}

            local servicesToScan = {
                game:GetService("ReplicatedStorage"),
                game:GetService("Workspace"),
                game:GetService("Lighting"),
                game:GetService("StarterGui"),
                game:GetService("SoundService"),
                game:GetService("MaterialService")
            }

            if LP and LP:FindFirstChild("PlayerScripts") then
                table.insert(servicesToScan, LP.PlayerScripts)
            end
            if LP and LP:FindFirstChild("PlayerGui") then
                table.insert(servicesToScan, LP.PlayerGui)
            end
            if LP and LP.Character then
                table.insert(servicesToScan, LP.Character)
            end

            local totalObjects = 0

            for _, svc in ipairs(servicesToScan) do
                pcall(function()
                    for _, obj in ipairs(svc:GetDescendants()) do
                        totalObjects = totalObjects + 1
                        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
                            table.insert(remotesFound, obj)
                        elseif obj:IsA("ModuleScript") then
                            table.insert(modulesFound, obj)
                        elseif obj:IsA("ProximityPrompt") then
                            table.insert(promptsFound, obj)
                        end
                    end
                end)
            end

            table.insert(fullOutput, "----------------------------------------------------------------------")
            table.insert(fullOutput, "-- [AXIONHUB DUMP: READY-TO-SCRIPT WORKSPACE]")
            table.insert(fullOutput, "-- Place ID: " .. tostring(game.PlaceId) .. " | Job ID: " .. game.JobId)
            table.insert(fullOutput, "-- Generated: " .. os.date("%Y-%m-%d %H:%M:%S"))
            table.insert(fullOutput, "----------------------------------------------------------------------\n")

            table.insert(fullOutput, "--------------------------------------------------")
            table.insert(fullOutput, "-- 1. SCRIPT STARTER BOILERPLATE (COPY & PASTE)")
            table.insert(fullOutput, "--------------------------------------------------")
            table.insert(fullOutput, [[
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local LP = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local HRP = Char:WaitForChild("HumanoidRootPart")

local function fireRemote(remote, ...)
    if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
        remote:FireServer(...)
    elseif remote:IsA("RemoteFunction") then
        return remote:InvokeServer(...)
    end
end
]])

            table.insert(fullOutput, "\n--------------------------------------------------")
            table.insert(fullOutput, "-- 2. DISCOVERED REMOTES (" .. #remotesFound .. " Remotes)")
            table.insert(fullOutput, "--------------------------------------------------")
            table.insert(fullOutput, "local remotes = {}")
            for i, rem in ipairs(remotesFound) do
                pcall(function()
                    table.insert(fullOutput, string.format("remotes[%d] = %s -- Class: %s", i, getCleanPath(rem), rem.ClassName))
                end)
            end

            table.insert(fullOutput, "\n--------------------------------------------------")
            table.insert(fullOutput, "-- 3. CONFIG & DATA MODULES (" .. #modulesFound .. " Modules)")
            table.insert(fullOutput, "--------------------------------------------------")
            for _, mod in ipairs(modulesFound) do
                pcall(function()
                    table.insert(fullOutput, string.format("-- [%s] %s", mod.Name, getCleanPath(mod)))
                end)
            end

            table.insert(fullOutput, "\n--------------------------------------------------")
            table.insert(fullOutput, "-- 4. PROXIMITY PROMPTS (" .. #promptsFound .. " Prompts)")
            table.insert(fullOutput, "--------------------------------------------------")
            for _, prm in ipairs(promptsFound) do
                pcall(function()
                    table.insert(fullOutput, string.format("-- Action: '%s' | Object: '%s' | Path: %s", prm.ActionText, prm.ObjectText, getCleanPath(prm)))
                end)
            end

            table.insert(fullOutput, "\n--------------------------------------------------")
            table.insert(fullOutput, "-- 5. COMPLETE HIERARCHY TREE")
            table.insert(fullOutput, "--------------------------------------------------")

            local function scanBranch(parentInstance, depth)
                for _, child in ipairs(parentInstance:GetChildren()) do
                    table.insert(fullOutput, formatTree(child, depth))

                    if SettingsToolkit.DecompileSource and child:IsA("ModuleScript") then
                        local indent = string.rep("    ", depth + 1)
                        table.insert(fullOutput, indent .. "/* [SOURCE CODE: " .. child.Name .. "] */")
                        local success, code = pcall(function()
                            return decompile and decompile(child) or "-- Decompile unsupported"
                        end)
                        if success and code and code ~= "" then
                            for line in string.gmatch(code, "[^\r\n]+") do
                                table.insert(fullOutput, indent .. line)
                            end
                        end
                        table.insert(fullOutput, indent .. "/* [END SOURCE] */\n")
                    end
                    scanBranch(child, depth + 1)
                end
            end

            for _, root in ipairs(servicesToScan) do
                pcall(function()
                    table.insert(fullOutput, string.format("\n[ ROOT SERVICE: %s ]", root.Name))
                    table.insert(fullOutput, string.rep("-", 40))
                    scanBranch(root, 0)
                end)
            end

            local elapsed = string.format("%.2f", os.clock() - startTime)
            local fileName = string.format("AxionHubScriptDump_%s.txt", tostring(game.PlaceId))

            if writefile then
                writefile(fileName, table.concat(fullOutput, "\n"))
                setStatusToolkit("Done! Saved " .. fileName)
                WindUI:Notify({ Title = "Success", Content = "Saved " .. fileName, Icon = "check", Duration = 4 })
            end
            SettingsToolkit.IsRunning = false
        end)
    end
})

-- ==============================================================================
-- TAB 2: REMOTE DUMPER & RUNTIME SPY
-- ==============================================================================
local RemoteTab = Window:Tab({ Title = L("Tab2"), Icon = "radio" })

local isDumpingRemotes = false
local remSec = RemoteTab:Section({
    Opened = true,
    Title = L("RemoteSecTitle"),
    Desc = L("RemoteSecDesc")
})

local remoteStatusPara = remSec:Paragraph({
    Title = "Status",
    Desc = L("Ready")
})

local function setRemoteStatus(msg)
    pcall(function() remoteStatusPara:SetDesc(tostring(msg)) end)
end

local function dumpAllRemotes()
    if isDumpingRemotes then return end
    isDumpingRemotes = true
    setRemoteStatus("Scanning...")

    task.spawn(function()
        local remotesFound = {}
        local fullOutput = {}
        local servicesToScan = {
            game:GetService("ReplicatedStorage"),
            game:GetService("Workspace"),
            game:GetService("Lighting"),
            game:GetService("StarterGui"),
            game:GetService("SoundService"),
            game:GetService("MaterialService")
        }

        for _, svc in ipairs(servicesToScan) do
            pcall(function()
                for _, obj in ipairs(svc:GetDescendants()) do
                    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
                        table.insert(remotesFound, obj)
                    end
                end
            end)
        end

        table.insert(fullOutput, "==================================================")
        table.insert(fullOutput, "           XEXER ALL REMOTES DUMP REPORT          ")
        table.insert(fullOutput, "==================================================\n")

        for i, rem in ipairs(remotesFound) do
            pcall(function()
                local path = getCleanPath(rem)
                local callSyntax = rem:IsA("RemoteFunction") and ":InvokeServer(...)" or ":FireServer(...)"
                table.insert(fullOutput, string.format("[%d] %s\n    Path : %s\n    Usage: %s%s\n", i, rem.Name, path, path, callSyntax))
            end)
        end

        local fileName = string.format("AxionHub_AllRemotes_%s.txt", tostring(game.PlaceId))
        if writefile then
            writefile(fileName, table.concat(fullOutput, "\n"))
            setRemoteStatus("Saved: " .. fileName)
            WindUI:Notify({ Title = "Success", Content = "Saved " .. fileName, Icon = "check", Duration = 4 })
        end
        isDumpingRemotes = false
    end)
end

remSec:Button({
    Title = L("DumpRemotesBtn"),
    Desc = L("DumpRemotesDesc"),
    Callback = function() dumpAllRemotes() end
})

local spySec = RemoteTab:Section({
    Opened = true,
    Title = L("SpyTitle"),
    Desc = L("SpyDesc")
})

local spiedCalls = {}
local isSpyingActive = false

local spyStatusPara = spySec:Paragraph({
    Title = "Status",
    Desc = L("Ready")
})

local function updateSpyStatus(msg)
    pcall(function() spyStatusPara:SetDesc(msg .. " (Captured: " .. #spiedCalls .. ")") end)
end

pcall(function()
    if hookmetamethod and getnamecallmethod then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            if isSpyingActive then
                local method = getnamecallmethod()
                if method == "FireServer" or method == "InvokeServer" or method == "fireserver" or method == "invokeserver" then
                    if typeof(self) == "Instance" and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction") or self:IsA("UnreliableRemoteEvent")) then
                        table.insert(spiedCalls, {
                            Name = self.Name,
                            Class = self.ClassName,
                            Path = getCleanPath(self),
                            Method = method,
                            Arguments = {...},
                            Time = os.date("%H:%M:%S")
                        })
                        -- updateSpyStatus ถูกถอดออกจาก hook เพื่อกัน UI lag spike
                        -- เกมยิง Remote ตลอดเวลา การ update UI ทุก call ทำให้ fps ตก
                        -- สถานะจะอัปเดตเมื่อกด Save หรือ Clear แทน
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
    end
end)

spySec:Toggle({
    Title = L("EnableSpy"),
    Desc = L("EnableSpyDesc"),
    Value = false,
    Callback = function(v)
        isSpyingActive = v
        updateSpyStatus(v and "Active" or "Paused")
    end
})

spySec:Button({
    Title = L("SaveSpyBtn"),
    Desc = L("SaveSpyDesc"),
    Callback = function()
        if #spiedCalls == 0 then return end
        local output = {}
        table.insert(output, "==================================================")
        table.insert(output, "       XEXER RUNTIME REMOTE SPY & ARGUMENTS       ")
        table.insert(output, "==================================================\n")

        for i, call in ipairs(spiedCalls) do
            table.insert(output, string.format("[%d] [%s] %s (%s)", i, call.Time, call.Name, call.Class))
            table.insert(output, string.format("    Path   : %s", call.Path))
            table.insert(output, string.format("    Method : :%s(...)", call.Method))
            table.insert(output, "    Args   :")
            for argIdx, argVal in ipairs(call.Arguments) do
                table.insert(output, string.format("      Arg #%d: %s", argIdx, serializeValue(argVal)))
            end
            table.insert(output, "")
        end

        local fileName = string.format("AxionHub_RemoteSpy_%s.txt", tostring(game.PlaceId))
        if writefile then
            writefile(fileName, table.concat(output, "\n"))
            WindUI:Notify({ Title = "Success", Content = "Saved " .. fileName, Icon = "check", Duration = 4 })
        end
    end
})

spySec:Button({
    Title = L("ClearSpyBtn"),
    Desc = L("ClearSpyDesc"),
    Callback = function()
        spiedCalls = {}
        updateSpyStatus("Cleared")
    end
})

-- ==============================================================================
-- TAB 3: DUMP EXPLORER
-- ==============================================================================
local DumpTab = Window:Tab({ Title = L("Tab3"), Icon = "folder-archive" })

local SettingsExplorer = {
    Target = TARGET_OPTIONS[1],
    IncludeSource = false,
    IsDumping = false
}

local cfgSec = DumpTab:Section({
    Opened = true,
    Title = L("ConfigSec"),
    Desc = L("ConfigDesc")
})

cfgSec:Dropdown({
    Title = L("TargetDrop"),
    Desc = L("TargetDesc"),
    Values = TARGET_OPTIONS,
    Value = SettingsExplorer.Target,
    Callback = function(val)
        SettingsExplorer.Target = val
    end
})

cfgSec:Toggle({
    Title = L("DecompileExp"),
    Desc = L("DecompileExpDesc"),
    Value = false,
    Callback = function(val)
        SettingsExplorer.IncludeSource = val
    end
})

local actionSec = DumpTab:Section({
    Opened = true,
    Title = L("ExecSec"),
    Desc = L("ExecDesc")
})

local statusParaExplorer = actionSec:Paragraph({
    Title = "Status",
    Desc = L("Ready")
})

actionSec:Button({
    Title = L("StartDumpBtn"),
    Desc = L("StartDumpDesc"),
    Callback = function()
        if SettingsExplorer.IsDumping then return end
        SettingsExplorer.IsDumping = true

        task.spawn(function()
            local targetRoots = {}
            local selected = SettingsExplorer.Target

            if selected == "[All Services - Full Dump]" then
                for _, s in ipairs(game:GetChildren()) do
                    pcall(function() table.insert(targetRoots, s) end)
                end
            elseif selected == "PlayerScripts" then
                if LP and LP:FindFirstChild("PlayerScripts") then table.insert(targetRoots, LP.PlayerScripts) end
            elseif selected == "PlayerGui" then
                if LP and LP:FindFirstChild("PlayerGui") then table.insert(targetRoots, LP.PlayerGui) end
            elseif selected == "LocalPlayer Character" then
                if LP and LP.Character then table.insert(targetRoots, LP.Character) end
            else
                local found = game:FindFirstChild(selected)
                if found then table.insert(targetRoots, found) end
            end

            local output = {}
            table.insert(output, "==================================================")
            table.insert(output, "               XEXER DATA DUMP REPORT             ")
            table.insert(output, "==================================================\n")

            local totalObjects = 0
            local function scanHierarchy(parentInstance, depth)
                for _, child in ipairs(parentInstance:GetChildren()) do
                    totalObjects = totalObjects + 1
                    table.insert(output, formatTree(child, depth))
                    if SettingsExplorer.IncludeSource and child:IsA("ModuleScript") then
                        local indent = string.rep("    ", depth + 1)
                        table.insert(output, indent .. "/* [SOURCE] */")
                        local success, code = pcall(function() return decompile and decompile(child) or "-- Unported" end)
                        if success and code then
                            for line in string.gmatch(code, "[^\r\n]+") do
                                table.insert(output, indent .. line)
                            end
                        end
                        table.insert(output, indent .. "/* [END] */\n")
                    end
                    scanHierarchy(child, depth + 1)
                end
            end

            for _, root in ipairs(targetRoots) do
                pcall(function()
                    table.insert(output, string.format("\n[ ROOT SERVICE: %s ]", root.Name))
                    scanHierarchy(root, 0)
                end)
            end

            local safeName = selected:gsub("%W", "")
            local fileName = string.format("AxionHubDump_%s_%s.txt", safeName, tostring(game.PlaceId))

            if writefile then
                writefile(fileName, table.concat(output, "\n"))
                WindUI:Notify({ Title = "Success", Content = "Saved " .. fileName, Icon = "check", Duration = 4 })
            end
            SettingsExplorer.IsDumping = false
        end)
    end
})

task.spawn(function()
    task.wait(0.5)
    pcall(function() Window:SelectTab(ToolTab) end)
end)

-- RightShift toggles the main panel; the floating Axion-style button remains available on touch devices.
pcall(function()
    game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.RightShift and AxionWindow then
            AxionWindow.Visible = not AxionWindow.Visible
        end
    end)
end)

end)
_G.__PartOK = __ok
_G.__PartErr = tostring(__err):sub(1, 500)
