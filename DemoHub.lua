-- DemoHub.lua — same idea as before, but now using AxionLib's bundled
-- Home page (greeting/clock, game info, performance, quick actions) instead
-- of building it by hand.

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
-- `Home` is bundled by the library itself: pass options and it builds the
-- greeting/game-info/performance/quick-actions page as the first tab.
-- Any custom tabs in `Tabs` are appended after it.

local window = AxionLib.new({
	Title = "DemoHub",
	Subtitle = "v1",
	Home = {
		Actions = {
			{
				Label = "Say Hi",
				Icon = "zap",
				Width = 94,
				Callback = function()
					window:Notify("Hello!", window.theme.good)
				end,
			},
			{
				Label = "Copy Link",
				Icon = "link",
				Width = 110,
				Callback = function()
					if setclipboard then
						setclipboard(("https://roblox.com/games/%d"):format(game.PlaceId))
						window:Notify("Copied game link", window.theme.good)
					end
				end,
			},
		},
	},
	Tabs = {
		{ Id = "SETTINGS", Icon = "settings", Label = "Settings", Desc = "options" },
	},
})

window:SetStatus("● ready")

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
