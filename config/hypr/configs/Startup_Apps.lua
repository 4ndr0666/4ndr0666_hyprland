-- File: configs/Startup_Apps.lua
-- /* ----  https://github.com/4ndr0666  ---- */
-- Startup Apps

local scriptsDir = os.getenv("HOME") .. "/.config/hypr/scripts"
local UserScripts = os.getenv("HOME") .. "/.config/hypr/UserScripts"
local wallDIR = os.getenv("HOME") .. "/Wallpapers"
local function shell_quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

hl.on("hyprland.start", function ()
    -- WallpaperAutoChange is an optional initial-install setup and remains disabled by default.
    -- hl.exec_cmd(UserScripts .. "/WallpaperAutoChange.sh " .. wallDIR)
    hl.exec_cmd(UserScripts .. "/4ndr0init.sh")

    -- Warm-spawn the dropdown terminal hidden in special:scratchpad
    hl.exec_cmd(scriptsDir .. "/Dropterminal.sh kitty &")

    -- System Applets
    -- Launch NM applets only for an already active NM backend. The Pi keeps
    -- networkd/wpa_supplicant; no applet may activate a competing owner.
    hl.exec_cmd("python3 " .. shell_quote(UserScripts .. "/NetworkBackend.py") .. " applets")
    hl.exec_cmd("hypridle")

    -- Clipboard manager
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("sh -c 'if test -x /usr/bin/mem-police; then exec /usr/bin/mem-police; fi'")
end)

return true
