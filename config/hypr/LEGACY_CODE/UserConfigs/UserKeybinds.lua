-- File: UserConfigs/UserKeybinds.lua
-- /* ---- 💫 https://github.com/4ndr0666 💫 ---- */  #
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
hl.bind(mainMod .. " + F10", hl.dsp.exec_cmd("nohup mpv --profile=playdir &"), { description = "MPV" })
hl.bind(mainMod .. " + SHIFT + F10", hl.dsp.exec_cmd("bash /home/andro/.local/bin/wofi_media.sh >/dev/null 2>&1"), { description = "Wofi Media" })

-- F12
hl.bind(mainMod .. " + F12", hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.local/bin/dmenurecord &"), { description = "Dmenurecord" })
-- Segment 2