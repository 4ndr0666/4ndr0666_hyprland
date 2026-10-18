-- File: UserConfigs/Laptops.lua
-- /* ----  https://github.com/4ndr0666  ---- */  #
-- Laptop-specific configuration, touchpad device identifier, and hardware hotkeys.
-- Use `hyprctl devices` to find your system touchpad device name for TouchPad.sh.

local scriptsDir = os.getenv("HOME") .. "/.config/hypr/scripts"
local Touchpad_Device = ""

-- Laptop display and keyboard backlight controls
hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd(scriptsDir .. "/BrightnessKbd.sh --inc"), { repeating = true, locked = true, description = "keyboard brightness up" })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd(scriptsDir .. "/BrightnessKbd.sh --dec"), { repeating = true, locked = true, description = "keyboard brightness down" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(scriptsDir .. "/Brightness.sh --inc"), { repeating = true, locked = true, description = "screen brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(scriptsDir .. "/Brightness.sh --dec"), { repeating = true, locked = true, description = "screen brightness down" })
hl.bind("XF86TouchpadToggle", hl.dsp.exec_cmd(scriptsDir .. "/TouchPad.sh"), { locked = true, description = "toggle touchpad" })

-- ASUS ROG / laptop hardware utility hotkeys (from historical configs/Laptops.conf)
hl.bind("XF86Launch1", hl.dsp.exec_cmd("rog-control-center"), { description = "ASUS ROG Control Center" })
hl.bind("XF86Launch3", hl.dsp.exec_cmd("asusctl led-mode -n"), { description = "switch keyboard RGB profile" })
hl.bind("XF86Launch4", hl.dsp.exec_cmd("asusctl profile -n"), { description = "cycle ASUS fan profile" })
hl.bind("ALT + F6", hl.dsp.exec_cmd(scriptsDir .. "/ScreenShot.sh --active"), { description = "screenshot active window (laptop F6)" })

if Touchpad_Device ~= "" then
    hl.device({
        name = Touchpad_Device,
        enabled = true,
    })
end

return true
