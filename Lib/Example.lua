-- Check for table that is shared between executions.
if not shared then
	return warn("No shared, no script.")
end

-- Load the library (replace the URL with your raw link).
local response = request({
	Url = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/AxionLib.lua",
	Method = "GET",
})

local AxionLib = loadstring(response.Body)()

local Hub = AxionLib:CreateWindow({
	Name = "AxionHub",
	Subtitle = "AutoDice",
	Version = "v22",
	Loading = true,
	Protection = {
		Name = "AFK & Safe",
		Description = "24/7 · anti-ban",
		Icon = "sliders-horizontal",
	},
})

-- Main tab.
local Main = Hub:AddTab({ Name = "Main", Description = "dice & collect", Icon = "activity" })

Main:AddSection("Dice")

Main:AddToggle({
	Name = "Auto Roll",
	Flag = "autoRoll",
	Default = false,
	Callback = function(value)
		-- Use Hub.Flags.autoRoll inside your loops.
	end,
})

Main:AddSlider({
	Name = "Roll Delay",
	Flag = "rollDelay",
	Min = 0.1,
	Max = 2,
	Default = 0.5,
	Increment = 0.1,
	Suffix = "s",
})

Main:AddDropdown({
	Name = "Dice Type",
	Flag = "diceType",
	Options = { "Basic", "Golden", "Rainbow" },
	Default = "Basic",
})

Main:AddSection("Collect")

Main:AddButton({
	Name = "Collect All",
	Style = "Accent",
	Callback = function()
		Hub:Notify("Collected!", "good")
	end,
})

-- Settings tab.
local Settings = Hub:AddTab({ Name = "Settings", Description = "animation / range", Icon = "settings" })

Settings:AddSection("Range")

Settings:AddSlider({ Name = "Collect Range", Flag = "range", Min = 10, Max = 200, Default = 60, Suffix = " st" })
Settings:AddTextbox({ Name = "Webhook", Flag = "webhook", Placeholder = "https://..." })
Settings:AddKeybind({ Name = "Toggle Farm", Flag = "farmKey", Default = Enum.KeyCode.F })

-- Example loop reading flags.
task.spawn(function()
	while Hub.alive do
		task.wait(Hub.Flags.rollDelay or 0.5)

		if Hub.Flags.autoRoll then
			-- your roll logic here
		end
	end
end)
