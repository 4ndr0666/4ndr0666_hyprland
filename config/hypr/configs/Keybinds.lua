-- File: configs/Keybinds.lua
-- /* ----  https://github.com/4ndr0666  ---- */
-- Default Keybinds

local mainMod = "SUPER"
local scriptsDir = os.getenv("HOME") .. "/.config/hypr/scripts"
local UserConfigs = os.getenv("HOME") .. "/.config/hypr/UserConfigs"
local UserScripts = os.getenv("HOME") .. "/.config/hypr/UserScripts"
local term = _G.user_defaults and _G.user_defaults.term or "kitty"
local files = _G.user_defaults and _G.user_defaults.files or "thunar"

-- MENU
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("pkill rofi || true && rofi -show drun -modi drun,filebrowser,run,window"), { description = "app launcher" })

-- SEARCH KEYBINDS
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.exec_cmd(scriptsDir .. "/KeyBinds.sh"), { description = "search keybinds" })

-- HELP
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd(UserScripts .. "/KeyHints.sh"), { description = "help / cheat sheet" })

-- QUICK SETTINGS
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(scriptsDir .. "/4ndr0666_Quick_Settings.sh"), { description = "Quick settings menu" })

-- KEYBOARD LAYOUT
hl.bind("ALT_L + SHIFT_L", hl.dsp.exec_cmd(scriptsDir .. "/KeyboardLayout.sh switch"), { locked = true, non_consuming = true, description = "switch keyboard layout globally" })
hl.bind("SHIFT_L + ALT_L", hl.dsp.exec_cmd(scriptsDir .. "/Tak0-Per-Window-Switch.sh"), { locked = true, non_consuming = true, description = "switch keyboard layout per-window" })

-- WAYBAR MENUS
hl.bind(mainMod .. " + CTRL + ALT + B", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"), { description = "toggle waybar on/off" })
hl.bind(mainMod .. " + CTRL + B", hl.dsp.exec_cmd(scriptsDir .. "/WaybarStyles.sh"), { description = "waybar styles menu" })
hl.bind(mainMod .. " + ALT + B", hl.dsp.exec_cmd(scriptsDir .. "/WaybarLayout.sh"), { description = "waybar layout menu" })

-- WAYBAR REFRESH
hl.bind(mainMod .. " + ALT + R", hl.dsp.exec_cmd(scriptsDir .. "/Refresh.sh"), { description = "refresh bar and menus" })

-- QUICKSHELL
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(scriptsDir .. "/OverviewToggle.sh"), { description = "desktop overview" })

-- WINDOW SWITCHER
hl.bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd("rofi -show window"), { description = "window switcher" })

-- CLOSE WINDOW
hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "close active window" })

-- KILL WINDOW
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd(scriptsDir .. "/KillActiveProcess.sh"), { description = "Terminate active process" })

-- KILL HYPRLAND
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("hyprctl dispatch exit 0"), { description = "exit Hyprland" })

-- FULL SCREEN
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen(), { description = "fullscreen" })

-- FAKE FULL SCREEN
hl.bind(mainMod .. " + CTRL + F", hl.dsp.window.fullscreen({ mode = 1 }), { description = "maximize window" })

-- FLOATING
hl.bind(mainMod .. " + SPACE", hl.dsp.window.float({ action = "toggle" }), { description = "Float current window" })

-- ALL FLOATING
hl.bind(mainMod .. " + ALT + SPACE", hl.dsp.exec_cmd("hyprctl dispatch workspaceopt allfloat"), { description = "Float all windows" })

-- DESKTOP ZOOM
local function zoom_cursor(multiplier)
    local current = hl.get_config("cursor.zoom_factor") or 1
    current = math.max(1, current * multiplier)
    hl.config({ cursor = { zoom_factor = current } })
end

-- Reduced from 2x to 1.1x to account for native execution speed
hl.bind(mainMod .. " + SHIFT + mouse_up", function() zoom_cursor(1.2) end, { description = "zoom in" })
hl.bind(mainMod .. " + SHIFT + mouse_down", function() zoom_cursor(0.8) end, { description = "zoom out" })

-- BLUR
hl.bind(mainMod .. " + ALT + O", hl.dsp.exec_cmd(scriptsDir .. "/ChangeBlur.sh"), { description = "toggle blur" })

-- OPAQUE
hl.bind(mainMod .. " + CTRL + O", hl.dsp.exec_cmd("hyprctl dispatch setprop active opaque toggle"), { description = "toggle active window opacity" })

-- BROWSER
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("gtk-launch thorium-browser"), { description = "open default browser" })

-- WEB SEARCH
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd(UserScripts .. "/RofiSearch.sh"), { description = "web search" })

-- FILE MANAGER
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(files), { description = "file manager" })

-- CLIPBOARD
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd(scriptsDir .. "/ClipManager.sh"), { description = "clipboard manager" })

-- TERMINALS
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd(scriptsDir .. "/Dropterminal.sh " .. term), { description = "DropDown terminal" })
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(term), { description = "Open terminal" })
hl.bind(mainMod .. " + ALT + Return", hl.dsp.exec_cmd("/usr/local/bin/st"), { description = "St" })
hl.bind(mainMod .. " + CTRL + Return", hl.dsp.exec_cmd(UserScripts .. "/alacritty4ndr0666"), { description = "Alacritty" })

-- THEME SWITCHER
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(scriptsDir .. "/ThemeChanger.sh"), { description = "Global theme switcher using Wallust" })

-- ROFI THEME SELECTOR
hl.bind(mainMod .. " + CTRL + R", hl.dsp.exec_cmd(scriptsDir .. "/RofiThemeSelector.sh"), { description = "rofi theme selector" })

-- ROFI THEME SELECTOR MODIFIED
hl.bind(mainMod .. " + CTRL + SHIFT + R", hl.dsp.exec_cmd("pkill rofi || true && " .. scriptsDir .. "/RofiThemeSelector-modified.sh"), { description = "rofi theme selector (modified)" })

-- ROFI NETWORK
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(UserScripts .. "/RofiNetwork.sh"), { description = "rofi network manager" })

-- ROFI CALULATOR
hl.bind(mainMod .. " + ALT + C", hl.dsp.exec_cmd(UserScripts .. "/RofiCalc.sh"), { description = "calculator" })

-- HYPERSUNSET
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd(scriptsDir .. "/Hyprsunset.sh toggle"), { description = "toggle night light" })

-- ONLINE MUSIC
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd(UserScripts .. "/RofiBeats.sh"), { description = "online music" })

-- WALLPAPER
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(UserScripts .. "/WallpaperSelect.sh"), { description = "select wallpaper" })

-- WALLPAPER EFFECTS
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(UserScripts .. "/WallpaperEffects.sh"), { description = "wallpaper effects" })

-- RANDOM WALLPAPER
hl.bind("CTRL + ALT + W", hl.dsp.exec_cmd(UserScripts .. "/WallpaperRandom.sh"), { description = "random wallpaper" })

-- ANIMATIONS
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd(scriptsDir .. "/Animations.sh"), { description = "animations menu" })

-- EMOJI
hl.bind(mainMod .. " + ALT + E", hl.dsp.exec_cmd(scriptsDir .. "/RofiEmoji.sh"), { description = "emoji menu" })

-- LOCKSCREEN
hl.bind("CTRL + ALT + L", hl.dsp.exec_cmd(scriptsDir .. "/LockScreen.sh"), { description = "lock screen" })

-- WLOGOUT
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd(scriptsDir .. "/Wlogout.sh"), { description = "powermenu" })

-- HOTKEYS
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(scriptsDir .. "/Volume.sh --inc"), { repeating = true, locked = true, description = "volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(scriptsDir .. "/Volume.sh --dec"), { repeating = true, locked = true, description = "volume down" })
hl.bind("ALT + XF86AudioRaiseVolume", hl.dsp.exec_cmd(scriptsDir .. "/Volume.sh --inc-precise"), { repeating = true, locked = true, description = "volume up precise" })
hl.bind("ALT + XF86AudioLowerVolume", hl.dsp.exec_cmd(scriptsDir .. "/Volume.sh --dec-precise"), { repeating = true, locked = true, description = "volume down precise" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(scriptsDir .. "/Volume.sh --toggle-mic"), { locked = true, description = "toggle mic mute" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(scriptsDir .. "/Volume.sh --toggle"), { locked = true, description = "toggle mute" })
hl.bind("XF86Sleep", hl.dsp.exec_cmd("systemctl suspend"), { locked = true, description = "sleep" })
hl.bind("XF86Rfkill", hl.dsp.exec_cmd(scriptsDir .. "/AirplaneMode.sh"), { locked = true, description = "airplane mode" })

-- MEDIA CONTROLS
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(scriptsDir .. "/MediaCtrl.sh --pause"), { locked = true, description = "pause" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(scriptsDir .. "/MediaCtrl.sh --pause"), { locked = true, description = "play" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(scriptsDir .. "/MediaCtrl.sh --nxt"), { locked = true, description = "next track" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(scriptsDir .. "/MediaCtrl.sh --prv"), { locked = true, description = "previous track" })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd(scriptsDir .. "/MediaCtrl.sh --stop"), { locked = true, description = "stop" })

-- SCREENSHOTS
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(UserScripts .. "/RofiScreenshot.sh"), { description = "screenshot (Rofi)" })

-- RESIZE WINDOWS (Using native 0.56 hl.dispatch factory object for smooth repeating)
hl.bind(mainMod .. " + SHIFT + left",  function() hl.dispatch(hl.dsp.window.resize({ x = -50, y = 0, relative = true })) end, { repeating = true, description = "resize left (-50)" })
hl.bind(mainMod .. " + SHIFT + right", function() hl.dispatch(hl.dsp.window.resize({ x = 50, y = 0, relative = true })) end,  { repeating = true, description = "resize right (+50)" })
hl.bind(mainMod .. " + SHIFT + up",    function() hl.dispatch(hl.dsp.window.resize({ x = 0, y = -50, relative = true })) end, { repeating = true, description = "resize up (-50)" })
hl.bind(mainMod .. " + SHIFT + down",  function() hl.dispatch(hl.dsp.window.resize({ x = 0, y = 50, relative = true })) end,  { repeating = true, description = "resize down (+50)" })

-- MOVE WINDOWS
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.move({ direction = "l" }), { description = "move window left" })
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({ direction = "r" }), { description = "move window right" })
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.move({ direction = "u" }), { description = "move window up" })
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.move({ direction = "d" }), { description = "move window down" })

-- SWAP WINDOWS
hl.bind(mainMod .. " + ALT + left",  hl.dsp.window.swap({ direction = "l" }), { description = "swap window left" })
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.swap({ direction = "r" }), { description = "swap window right" })
hl.bind(mainMod .. " + ALT + up",    hl.dsp.window.swap({ direction = "u" }), { description = "swap window up" })
hl.bind(mainMod .. " + ALT + down",  hl.dsp.window.swap({ direction = "d" }), { description = "swap window down" })

-- GROUP
hl.bind(mainMod .. " + G", function() hl.dispatch("togglegroup") end, { description = "toggle group" })

-- MOVE FOCUS
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "l" }), { description = "focus left" })
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }), { description = "focus right" })
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "u" }), { description = "focus up" })
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "d" }), { description = "focus down" })

-- WORKSPACES
hl.bind(mainMod .. " + Tab",         hl.dsp.focus({ workspace = "m+1" }), { description = "next workspace" })
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "m-1" }), { description = "previous workspace" })
hl.bind(mainMod .. " + SHIFT + U",   hl.dsp.window.move({ workspace = "special" }), { description = "move to special workspace" })
hl.bind(mainMod .. " + U",           hl.dsp.workspace.toggle_special(), { description = "toggle special workspace" })

-- WORKSPACE MAPPING (code:10 to 19)
for i = 1, 10 do
    local key  = i % 10
    local code = 9 + (i == 10 and 10 or i)
    hl.bind(mainMod .. " + SHIFT + code:" .. code, hl.dsp.window.move({ workspace = i }),         { description = "move to workspace " .. key })
    hl.bind(mainMod .. " + CTRL + code:" .. code,  hl.dsp.window.move({ workspace = i, follow = false }), { description = "move silently to workspace " .. key })
end

hl.bind(mainMod .. " + SHIFT + bracketleft",  hl.dsp.window.move({ workspace = "-1" }),                 { description = "move to previous workspace" })
hl.bind(mainMod .. " + SHIFT + bracketright", hl.dsp.window.move({ workspace = "+1" }),                 { description = "move to next workspace" })
hl.bind(mainMod .. " + CTRL + bracketleft",   hl.dsp.window.move({ workspace = "-1", follow = false }), { description = "move silently to previous workspace" })
hl.bind(mainMod .. " + CTRL + bracketright",  hl.dsp.window.move({ workspace = "+1", follow = false }), { description = "move silently to next workspace" })

-- SCROLL WORKSPACES
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "next workspace" })
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { description = "previous workspace" })
hl.bind(mainMod .. " + period",     hl.dsp.focus({ workspace = "e+1" }), { description = "next workspace" })
hl.bind(mainMod .. " + comma",      hl.dsp.focus({ workspace = "e-1" }), { description = "previous workspace" })

-- MOUSE MOVE/RESIZE
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "move window" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "resize window" })
-- J/K LAYOUT-CONDITIONAL WINDOW NAVIGATION
local function cycle_or_focus(direction)
    local layout = hl.get_config("general.layout")
    if layout == "master" then
        hl.dispatch(hl.dsp.layout({ action = (direction == "down" and "cyclenext" or "cycleprev") }))
    else
        hl.dispatch(hl.dsp.focus({ direction = (direction == "down" and "d" or "u") }))
    end
end

hl.bind(mainMod .. " + J", function() cycle_or_focus("down") end, { description = "focus down / cycle next" })
hl.bind(mainMod .. " + K", function() cycle_or_focus("up") end,   { description = "focus up / cycle prev" })
