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

-- Retire the transitional layout-aware keybinds from configs.Keybinds.lua.
hl.unbind(mainMod .. " + J")
hl.unbind(mainMod .. " + K")
hl.unbind(mainMod .. " + M")
hl.unbind(mainMod .. " + O")
hl.unbind(mainMod .. " + ALT + L")
hl.unbind(mainMod .. " + SHIFT + I")

local function toggle_layout()
    local layout = hl.get_config("general.layout")
    local next_layout
    local message

    if layout == "dwindle" then
        next_layout = "master"
        message = "Master Layout"
    elseif layout == "master" then
        next_layout = "dwindle"
        message = "Dwindle Layout"
    else
        hl.notification.create({
            text = "Unsupported layout: " .. tostring(layout),
            timeout = 3000,
            icon = "error",
        })
        return
    end

    hl.config({
        general = {
            layout = next_layout,
        },
    })

    hl.notification.create({
        text = message,
        timeout = 2000,
        icon = "ok",
    })
end

-- Preserve the established machine workflow without the legacy shell state machine.
hl.bind(mainMod .. " + ALT + L", toggle_layout, { description = "toggle master/dwindle layout" })
hl.bind(mainMod .. " + SHIFT + I", hl.dsp.layout("removemaster"), { description = "remove master" })

-- Preserve the legacy split-ratio control, but use the native 0.56 layout API.
hl.bind(mainMod .. " + M", function()
    local layout = hl.get_config("general.layout")

    if layout == "master" then
        hl.dispatch(hl.dsp.layout("mfact +0.3"))
    elseif layout == "dwindle" then
        hl.dispatch(hl.dsp.layout("splitratio +0.3"))
    end
end, { description = "adjust current layout ratio" })
