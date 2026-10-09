-- DemoHub.lua — small example script using AxionLib + a custom icon pack,
-- both loaded straight from hosted URLs.

local LIB_URL = "https://raw.githubusercontent.com/alwayszoey/script-openv1/refs/heads/main/Lib/AxionLib.lua"
local ICONS_URL = "https://raw.githubusercontent.com/alwayszoey/script-openv1/refs/heads/main/assets/dist/Icons.lua"

local function fetch(url)
	local response = request({ Url = url, Method = "GET" })
	assert(response and response.Success, "failed to fetch " .. url)
	return response.Body
end

local AxionLib = loadstring(fetch(LIB_URL))()
AxionLib.LoadIconPack(ICONS_URL, "DemoHub/icons.lua")

--// Window -----------------------------------------------------------------

local window = AxionLib.new({
	Title = "DemoHub",
	Subtitle = "v1",
	Tabs = {
		{ Id = "HOME", Icon = "home", Label = "Home", Desc = "overview" },
		{ Id = "SETTINGS", Icon = "settings", Label = "Settings", Desc = "options" },
	},
})

window:SetStatus("● ready")

--// Home page ----------------------------------------------------------------

local home = window:GetPage("HOME")

local welcomeCard = window:Card(home, UDim2.new(1, -36, 0, 70), UDim2.new(0, 18, 0, 16))
window:Label(welcomeCard, "WELCOME", UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 10), {
	font = window.theme.fontBold,
	textSize = 9.5,
	color = window.theme.accentLight,
})
window:Label(welcomeCard, "This hub is built on AxionLib.", UDim2.new(1, -28, 0, 16), UDim2.new(0, 14, 0, 30))

local clicks = 0
local counterCard = window:Card(home, UDim2.new(1, -36, 0, 62), UDim2.new(0, 18, 0, 96))
local counterLabel = window:Label(counterCard, "Clicked 0 times", UDim2.new(1, -120, 1, 0), UDim2.new(0, 14, 0, 0), {
	font = window.theme.fontMedium,
	textSize = 12,
})

window:ActionChip(counterCard, UDim2.new(1, -108, 0, 16), 94, "Click me", "zap", function()
	clicks = clicks + 1
	counterLabel.Text = string.format("Clicked %d times", clicks)
	window:Notify("Thanks for clicking!", window.theme.good)
end)

--// Settings page --------------------------------------------------------------

local settings = window:GetPage("SETTINGS")
local settingsCard = window:Card(settings, UDim2.new(1, -36, 0, 150), UDim2.new(0, 18, 0, 16))

window:AddToggle(settingsCard, 6, "UI Sounds", window.soundsEnabled, function(value)
	window.soundsEnabled = value
end, "sound")

window:AddSlider(settingsCard, 56, "Demo Value", {
	min = 0,
	max = 100,
	default = 50,
	suffix = "%",
	onChange = function(value)
		window:SetStatus(("● value: %d%%"):format(value))
	end,
})

local copyCard = window:Card(settings, UDim2.new(1, -36, 0, 46), UDim2.new(0, 18, 0, 176))
window:ActionChip(copyCard, UDim2.new(0, 8, 0, 8), 140, "Copy a message", "copy", function()
	if setclipboard then
		setclipboard("Hello from DemoHub!")
		window:Notify("Copied to clipboard", window.theme.good)
	else
		window:Notify("Clipboard not supported", window.theme.bad)
	end
end)
