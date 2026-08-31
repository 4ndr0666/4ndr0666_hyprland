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
    local current = hl.get_config("cursor.zoom_factor")
    current = math.max(1, current * multiplier)
    hl.config({ cursor = { zoom_factor = current } })
end

hl.bind(mainMod .. " + ALT + mouse_down", function() zoom_cursor(2) end, { description = "zoom in" })
hl.bind(mainMod .. " + ALT + mouse_up", function() zoom_cursor(0.5) end, { description = "zoom out" })

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

-- HYPERSUNSET (Duplicate bind in legacy conf)
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

-- LAYOUTS
-- Layout controls are owned by UserConfigs/UserKeybinds.lua.

-- CYCLE; if floating bring to top (Native Dispatchers mapped)
hl.bind("ALT + Tab", hl.dsp.layout("cyclenext"), { description = "cycle next window" })

-- HOTKEYS
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(scriptsDir .. "/Volume.sh --inc"), { repeating = true, locked = true, description = "volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(scriptsDir .. "/Volume.sh --dec"), { repeating = true, locked = true, description = "volume down" })
hl.bind("ALT + XF86AudioRaiseVolume", hl.dsp.exec_cmd(scriptsDir .. "/Volume.sh --inc-precise"), { repeating = true, locked = true, description = "volume up precise" })
hl.bind("ALT + XF86AudioLowerVolume", hl.dsp.exec_cmd(scriptsDir .. "/Volume.sh --dec-precise"), { repeating = true, locked = true, description = "volume down precise" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(scriptsDir .. "/Volume.sh --toggle-mic"), { locked = true, description = "toggle mic mute" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(scriptsDir .. "/Volume.sh --toggle"), { locked = true, description = "toggle mute" })
hl.bind("XF86Sleep", hl.dsp.exec_cmd("systemctl suspend"), { locked = true, description = "sleep" })
hl.bind("XF86Rfkill", hl.dsp.exec_cmd(scriptsDir .. "/AirplaneMode.sh"), { locked = true, description = "airplane mode" })

-- media controls using keyboards
-- hl.bind("XF86AudioPlayPause", hl.dsp.exec_cmd(scriptsDir .. "/MediaCtrl.sh --pause"), { locked = true, description = "play/pause" }) -- Disabled: Invalid xkbcommon keysym
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(scriptsDir .. "/MediaCtrl.sh --pause"), { locked = true, description = "pause" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(scriptsDir .. "/MediaCtrl.sh --pause"), { locked = true, description = "play" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(scriptsDir .. "/MediaCtrl.sh --nxt"), { locked = true, description = "next track" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(scriptsDir .. "/MediaCtrl.sh --prv"), { locked = true, description = "previous track" })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd(scriptsDir .. "/MediaCtrl.sh --stop"), { locked = true, description = "stop" })

-- SCREENSHOTS
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(UserScripts .. "/RofiScreenshot.sh"), { description = "screenshot (Rofi)" })

-- RESIZE WINDOWS
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.resize({ x = -50, y = 0 }),  { repeating = true, description = "resize left (-50)" })
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = 50,  y = 0 }),  { repeating = true, description = "resize right (+50)" })
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.resize({ x = 0,   y = -50 }), { repeating = true, description = "resize up (-50)" })
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.resize({ x = 0,   y = 50 }),  { repeating = true, description = "resize down (+50)" })

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

-- GROUP (Native Dispatchers mapped)
hl.bind(mainMod .. " + G", function() hl.dispatch("togglegroup") end, { description = "toggle group" })
