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
hl.bind(mainMod .. " + F2", hl.dsp.exec_cmd(term .. " -e yazi --cwd-file " .. os.getenv("HOME") .. "/.cache/yazi/cwd_file"), { description = "Yazi" })

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
-- Hyprland 0.56 layout overrides
-- Machine-specific layout controls belong here, not in the defaults.
-- ============================================================================

-- Retire transitional layout-aware bindings from configs.Keybinds.lua.
hl.unbind(mainMod .. " + J")
hl.unbind(mainMod .. " + K")
hl.unbind(mainMod .. " + M")
hl.unbind(mainMod .. " + O")
hl.unbind(mainMod .. " + ALT + L")
hl.unbind(mainMod .. " + SHIFT + I")

-- J/K retain the established global next/previous-window behavior without
-- the legacy startup script or layout-dependent branching.
hl.bind(mainMod .. " + J", function() hl.dispatch("cyclenext") end, { description = "cycle next window" })
hl.bind(mainMod .. " + K", function() hl.dispatch("cyclenext", "prev") end, { description = "cycle previous window" })

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
hl.bind(mainMod .. " + SHIFT + I", hl.dsp.layout("removemaster"), { description = "remove master" })

-- Preserve the established layout-ratio control using native 0.56 dispatchers.
hl.bind(mainMod .. " + M", function()
    local layout = hl.get_config("general.layout")

    if layout == "master" then
        hl.dispatch("layoutmsg", "mfact +0.3")
    elseif layout == "dwindle" then
        hl.dispatch("layoutmsg", "splitratio +0.3")
    end
end, { description = "adjust current layout ratio" })
