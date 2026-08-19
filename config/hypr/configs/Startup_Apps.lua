-- File: configs/Startup_Apps.lua
-- /* ----  https://github.com/4ndr0666  ---- */  #
-- Startup Apps

local scriptsDir = os.getenv("HOME") .. "/.config/hypr/scripts"
local UserScripts = os.getenv("HOME") .. "/.config/hypr/UserScripts"
local wallDIR = os.getenv("HOME") .. "/Wallpapers"

hl.on("hyprland.start", function ()
    hl.exec_cmd(UserScripts .. "/WallpaperAutoChange.sh " .. wallDIR)
    hl.exec_cmd("awww-daemon --format xrgb")
    hl.exec_cmd(UserScripts .. "/4ndr0init.sh")

    -- Warm-spawn the dropdown terminal hidden in special:scratchpad
    hl.exec_cmd(scriptsDir .. "/Dropterminal.sh kitty &")

    -- System Applets
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("nm-tray")
    hl.exec_cmd("mako")
    hl.exec_cmd("waybar")
    hl.exec_cmd("hypridle")

    -- Clipboard manager
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("/usr/bin/mem-police")
end)
-- Segment 1
