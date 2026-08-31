-- File: UserConfigs/UserKeybinds.lua
-- /* ----  https://github.com/4ndr0666  ---- */
-- User Custom Keybinds

local mainMod = "SUPER"
local UserScripts = os.getenv("HOME") .. "/.config/hypr/UserScripts"
local term = _G.user_defaults and _G.user_defaults.term or "kitty"

-- Fkeyhints
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.exec_cmd(UserScripts .. "/Fkeyhints.sh"), { description = "Brave Keybinds" })

-- Colorpicker
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(UserScripts .. "/colorpicker"), { description = "Colorpicker" })

-- F2
hl.bind(mainMod .. " + F2", hl.dsp.exec_cmd(term .. " -e yazi " .. os.getenv("HOME") .. "/.cache/yazi"), { description = "Yazi" })

-- F3
hl.bind(mainMod .. " + F3", hl.dsp.exec_cmd(term .. " -e micro"), { description = "Micro" })
hl.bind(mainMod .. " + SHIFT + F3", hl.dsp.exec_cmd(term .. " -e nvim"), { description = "Neovim" })

-- F5
hl.bind(mainMod .. " + F5", hl.dsp.exec_cmd("python3 /usr/local/bin/play-with-mpv.py"), { description = "Play-with-mpv" })

-- F6
hl.bind(mainMod .. " + F6", hl.dsp.exec_cmd("/sbin/vidcut"), { description = "Vidcut" })
hl.bind(mainMod .. " + SHIFT + F6", hl.dsp.exec_cmd("losslesscut"), { description = "Losslesscut" })

-- F7
hl.bind(mainMod .. " + F7", hl.dsp.exec_cmd("jdownloader"), { description = "Jdownloader" })
hl.bind(mainMod .. " + SHIFT + F7", hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.local/bin/dmenuhandler"), { description = "Dmenuhandler" })

-- F8
hl.bind(mainMod .. " + F8", hl.dsp.exec_cmd("bash 4ndr0service"), { description = "4ndr0service" })
hl.bind(mainMod .. " + SHIFT + F8", hl.dsp.exec_cmd("bash /usr/local/bin/trigger_oom.sh"), { description = "OOM Killer" })

-- F9
hl.bind(mainMod .. " + F9", hl.dsp.exec_cmd(term .. " -e " .. os.getenv("HOME") .. "/.local/bin/torwrap /dev/null 2>&1"), { description = "Torwrap" })
hl.bind(mainMod .. " + SHIFT + F9", hl.dsp.exec_cmd("st -e python3 /home/git/clone/4ndr0666/scr/media/dorkmaster/dorkmaster.py"), { description = "Dorkmaster" })

-- F10
hl.bind(mainMod .. " + F10", hl.dsp.exec_cmd("mpv"), { description = "MPV" })
hl.bind(mainMod .. " + SHIFT + F10", hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.local/bin/wl-media >/dev/null 2>&1"), { description = "Wl-Media" })

-- F12
hl.bind(mainMod .. " + F12", hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.local/bin/wl-record >/dev/null 2>&1"), { description = "Wl-record" })

-- ============================================================================
-- Hyprland 0.56 layout controls
-- User-specific controls belong here; defaults remain in configs/Keybinds.lua.
-- ============================================================================

-- WORKSPACES
-- Focus uses the native Lua workspace dispatcher. The key name is the XKB
-- key, not the legacy KEY_1 form. Keep all numbered workspaces explicit so
-- SUPER+1 through SUPER+0 retain the standard direct workspace behavior.
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }), { description = "focus workspace 1" })
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }), { description = "focus workspace 2" })
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }), { description = "focus workspace 3" })
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }), { description = "focus workspace 4" })
hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }), { description = "focus workspace 5" })
hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }), { description = "focus workspace 6" })
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }), { description = "focus workspace 7" })
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }), { description = "focus workspace 8" })
hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }), { description = "focus workspace 9" })
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }), { description = "focus workspace 10" })

-- J/K Global Window Cycling
-- Dynamically routes the shell command based on layout to bypass Lua API strict validation.
local function cycle_window(direction)
    local layout = hl.get_config("general.layout")
    if layout == "master" then
        hl.dispatch(hl.dsp.exec_cmd("hyprctl dispatch layoutmsg " .. (direction == "next" and "cyclenext" or "cycleprev")))
    else
        hl.dispatch(hl.dsp.exec_cmd("hyprctl dispatch " .. (direction == "next" and "cyclenext" or "cycleprev")))
    end
end

hl.bind(mainMod .. " + J", function() cycle_window("next") end, { description = "cycle next window" })
hl.bind(mainMod .. " + K", function() cycle_window("prev") end, { description = "cycle previous window" })

-- Toggle the global compositor layout. This preserves the legacy
-- ChangeLayout.sh contract while using the native Lua configuration API.
local function toggle_layout()
    local current = hl.get_config("general.layout")
    local next_layout

    if current == "dwindle" then
        next_layout = "master"
    elseif current == "master" then
        next_layout = "dwindle"
    else
        return
    end

    hl.config({
        general = {
            layout = next_layout,
        },
    })

    hl.notification.create({
        text = next_layout == "master" and "Master Layout" or "Dwindle Layout",
        timeout = 2000,
        icon = "ok",
    })
end

hl.bind(mainMod .. " + ALT + L", toggle_layout, { description = "toggle master/dwindle layout" })
hl.bind(mainMod .. " + SHIFT + I", hl.dsp.exec_cmd("hyprctl dispatch layoutmsg removemaster"), { description = "remove master" })

-- Preserve the established layout-ratio control utilizing safe shell fallback.
hl.bind(mainMod .. " + M", function()
    local layout = hl.get_config("general.layout")
    if layout == "master" then
        hl.dispatch(hl.dsp.exec_cmd("hyprctl dispatch layoutmsg mfact +0.3"))
    elseif layout == "dwindle" then
        hl.dispatch(hl.dsp.exec_cmd("hyprctl dispatch splitratio +0.3"))
    end
end, { description = "adjust current layout ratio" })

-- MOVE WINDOWS
hl.bind(mainMod .. " + left", hl.dsp.window.move({ direction = "l" }), { description = "move window left" })
hl.bind(mainMod .. " + right", hl.dsp.window.move({ direction = "r" }), { description = "move window right" })
hl.bind(mainMod .. " + up", hl.dsp.window.move({ direction = "u" }), { description = "move window up" })
hl.bind(mainMod .. " + down", hl.dsp.window.move({ direction = "d" }), { description = "move window down" })
