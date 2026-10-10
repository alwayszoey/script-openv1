# AxionLib v2

UI Library ของ AxionHub — หน้า **Home**, Loading card, Anti-AFK / Auto Reconnect / Anti-Kick, ไอคอน (rbxassetid) และเสียง FX ติดมากับ Lib ทั้งหมด
สคริปต์ของคุณเขียนแค่หน้า Tab กับปุ่ม/สวิตช์ แล้ว Lib จัดสี, เลย์เอาต์ และการเลื่อนหน้าให้เอง

## ติดตั้ง

```lua
local response = request({ Url = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/AxionLib.lua", Method = "GET" })
local AxionLib = loadstring(response.Body)()
```

## เริ่มใช้งาน

```lua
local Hub = AxionLib:CreateWindow({
	Name = "AxionHub",
	Subtitle = "AutoDice",
	Version = "v22",
	Loading = true,
})

local Main = Hub:AddTab({ Name = "Main", Description = "dice & collect", Icon = "activity" })

Main:AddSection("Dice")
Main:AddToggle({ Name = "Auto Roll", Flag = "autoRoll", Callback = function(on) end })
Main:AddButton({ Name = "Collect All", Style = "Accent", Callback = function() end })
```

ดูตัวอย่างเต็มใน `Example.lua`

## ลำดับการแสดงผล (Loading)

1. การ์ด Loading ขึ้น (ถ้า `Loading = true`)
2. โหลด config / ไอคอน / ระบบป้องกัน / สร้าง UI แบบซ่อน
3. สคริปต์ของคุณเพิ่ม Tab และปุ่มต่างๆ
4. บาร์ Loading เต็ม 100% แล้วการ์ดจางหายไปจนหมด
5. **จากนั้น** หน้าต่าง UI จึงค่อยขึ้น

`Ready` จะถูกเรียกอัตโนมัติหลังสคริปต์ส่วนที่สร้าง UI จบ ถ้าสคริปต์คุณมี `task.wait` / yield ก่อนสร้าง Tab ให้ใช้:

```lua
local Hub = AxionLib:CreateWindow({ AutoReady = false })
-- ... สร้าง Tab / ปุ่มทั้งหมด ...
Hub:Ready()
```

## CreateWindow options

| Option | ค่าเริ่มต้น | คำอธิบาย |
| --- | --- | --- |
| `Name` | `"AxionHub"` | ชื่อบน Sidebar และ Loading card |
| `Subtitle` | `"Script Hub"` | ข้อความใต้ชื่อ |
| `Version` | `"v22"` | เวอร์ชันต่อท้าย Subtitle |
| `Loading` | `true` | `false` = ไม่มีหน้า Loading |
| `AutoReady` | `true` | `false` = เรียก `Hub:Ready()` เอง |
| `Protection` | `true` | `false` = ซ่อนหน้า Settings ในตัว, หรือ `{ Name, Description, Icon }` เพื่อเปลี่ยนชื่อ/ไอคอน |
| `ToggleKey` | `RightShift` | ปุ่มย่อ/เปิด UI, `false` = ปิด |
| `Theme` | - | เปลี่ยนสี (ดูด้านล่าง) |
| `Icons` | - | เพิ่มไอคอนเอง `{ myicon = 123456 }` |
| `ConfigFolder` | `"AxionHub"` | โฟลเดอร์เก็บ config / flags / logo |
| `SaveFlags` | `true` | เซฟค่า Flag ลงไฟล์อัตโนมัติ |
| `ReloadFile` | `"AxionHub.lua"` | ไฟล์ที่ queue_on_teleport โหลดซ้ำ |
| `LogoUrl` / `IconsUrl` | ของเดิม | ลิงก์โลโก้ / dist ไอคอน |
| `OnReady` | - | ฟังก์ชันที่เรียกตอน UI ขึ้นแล้ว |

## Hub

| เมธอด | ทำอะไร |
| --- | --- |
| `Hub:AddTab({ Name, Description, Icon })` | สร้าง Tab ใหม่ |
| `Hub:Notify(text, kind)` | Toast (`"good"`, `"bad"`, `"muted"` หรือ Color3) |
| `Hub:SelectTab(tab)` | สลับหน้า (`"Home"` ก็ได้) |
| `Hub:Toggle()` | ย่อ / เปิดหน้าต่าง |
| `Hub:Ready()` | แสดง UI (เมื่อ `AutoReady = false`) |
| `Hub:GetSetting(key)` | อ่านค่า `antiAfk`, `antiKick`, `safeMode`, `autoResume`, ... |
| `Hub:SaveFlags()` | เซฟ Flag ทันที |
| `Hub:Destroy()` | ปิดทุกอย่าง |
| `Hub.Flags` | ตารางค่าทุก Flag (`Hub.Flags.autoRoll`) |
| `Hub.alive` | `false` เมื่อ UI ถูกปิด (ใช้เป็นเงื่อนไข loop) |

## Tab / Section

```lua
local tab = Hub:AddTab({ ... })
tab:AddSection("Title")   -- การ์ดใหม่ (Element ที่เพิ่มหลังจากนี้จะเข้าการ์ดนี้)
tab:SetStatus("Farming...", Color3.fromRGB(130, 255, 180))
tab:Select()
```

ถ้าไม่เรียก `AddSection` ก่อน Element จะถูกใส่การ์ดที่ไม่มีหัวข้อให้อัตโนมัติ
`AddSection` คืน Section ที่มีเมธอด `Add...` เหมือน Tab

## Elements

ทุก Element มี `Flag` (ชื่อสำหรับเซฟ/โหลดค่า), `:Set()`, `:Get()`, `:SetVisible(bool)`, `:Destroy()`
ถ้ามีค่าที่เซฟไว้ Callback จะถูกเรียกอัตโนมัติหลังสร้างเสร็จ

| Element | Options | Callback |
| --- | --- | --- |
| `AddToggle` | `Name, Default, Flag, Icon` | `(value: boolean)` |
| `AddButton` | `Name, Icon, Style` (`"Default"` / `"Accent"`) | `()` |
| `AddSlider` | `Name, Min, Max, Default, Increment, Suffix, Flag` | `(value: number)` |
| `AddDropdown` | `Name, Options, Default, Multi, Placeholder, Flag` | `(value)` — string หรือ array (Multi) |
| `AddTextbox` | `Name, Default, Placeholder, Numeric, Flag` | `(text, enterPressed)` |
| `AddKeybind` | `Name, Default, Flag` | `Callback(key)` ตอนกดปุ่ม, `OnChanged(key)` ตอนเปลี่ยนปุ่ม |
| `AddLabel` | `Text, Color` | - |
| `AddParagraph` | `Title, Text` | - |
| `AddCustom(height)` | - | คืน Frame เปล่าไว้สร้าง UI เอง |

เมธอดเฉพาะ: `Button:SetText()`, `Button:SetCallback()`, `Dropdown:SetOptions(list)`, `Label:Set(text)`, `Paragraph:Set(title, text)`

## เปลี่ยนสี (Theme)

```lua
AxionLib:CreateWindow({
	Theme = {
		accentBlue = Color3.fromRGB(0, 120, 255),
		accentPink = Color3.fromRGB(0, 220, 200),
		accentLight = Color3.fromRGB(160, 230, 255),
	},
})
```

คีย์ที่ใช้ได้: `accentBlue, accentPink, accentLight, bgTop, bgBot, sidebarTop, sidebarBot, cardTop, cardBot, chipOff, chipHover, track, text, textDim, muted, good, bad, font, fontBold, fontMedium, blurSize`
(เปลี่ยนได้ตอน `CreateWindow` เท่านั้น)

## สร้าง UI เองให้หน้าตาเหมือน Lib

```lua
local row = Main:AddCustom(40)
local chip = AxionLib.UI.Chip(row, UDim2.new(1, -28, 0, 30), UDim2.new(0, 14, 0.5, -15), "My Button", 11, 999)
AxionLib.UI.AddHover(chip)
chip.button.MouseButton1Click:Connect(function()
	AxionLib:PlaySound("Click")
end)
```

`AxionLib.UI` มี: `Card, Chip, Label, Icon, Corner, Gradient, Stroke, AccentSequence, Tween, AddHover, StyleChip, Toggle`
`AxionLib.Theme` คือตารางสีที่ใช้อยู่ (อ้างอิงตรง ใช้สีให้ตรงกับ Lib ได้เลย)

## ไอคอนและเสียง (ติดมากับ Lib)

- ไอคอนใช้ชื่อ lucide (`"settings"`, `"activity"`), `rbxassetid://...` หรือตัวเลขก็ได้
- Lib มี dist ไอคอนหลักฝังในตัว (`EMBEDDED_DIST`) แล้วโหลด `Icons.lua` จาก `IconsUrl` มา merge เพิ่ม (cache ไว้ที่ `ConfigFolder/icons.lua`) ทำให้ออฟไลน์ก็ยังใช้ไอคอนหลักได้
- อยากฝัง dist ทั้งก้อน: วางรายการ `["ชื่อ"] = id` ลงใน `EMBEDDED_DIST` ที่หัวไฟล์ `AxionLib.lua`
- เสียง: `Click, ToggleOn, ToggleOff, TabSwitch, Dropdown, Notify` (`AxionLib:PlaySound("Click")`)

## ไฟล์ที่ Lib สร้างใน workspace

`ConfigFolder/config.json` (ค่า Protection), `flags_<PlaceId>.json` (ค่า Flag แยกตามเกม), `logo.png`, `icons.lua`
