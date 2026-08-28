-- File: configs/WindowRules-pre-53.lua
-- /* ---- 💫 https://github.com/4ndr0666 💫 ---- */  #
-- Vendor defaults for window rules and layerrules
-- Notes: Ported for Hyprland > 0.48

-- browser tags
hl.window_rule({ tag = "+browser", match = { class = "^([Ff]irefox|org.mozilla.firefox|[Ff]irefox-esr|[Ff]irefox-bin)$" } })
hl.window_rule({ tag = "+browser", match = { class = "^([Gg]oogle-chrome(-beta|-dev|-unstable)?)$" } })
hl.window_rule({ tag = "+browser", match = { class = "^(chrome-.+-Default)$" } })
hl.window_rule({ tag = "+browser", match = { class = "^([Cc]hromium)$" } })
hl.window_rule({ tag = "+browser", match = { class = "^([Mm]icrosoft-edge(-stable|-beta|-dev|-unstable))$" } })
hl.window_rule({ tag = "+browser", match = { class = "^(Brave-browser(-beta|-dev|-unstable)?)$" } })
hl.window_rule({ tag = "+browser", match = { class = "^([Tt]horium-browser|[Cc]achy-browser)$" } })
hl.window_rule({ tag = "+browser", match = { class = "^(zen-alpha|zen)$" } })

-- notif tags
hl.window_rule({ tag = "+notif", match = { class = "^(swaync-control-center|swaync-notification-window|swaync-client|class)$" } })

-- 4ndr0666 settings tag
hl.window_rule({ tag = "+4ndr0666_Cheat", match = { title = "^(4ndr0666 Quick Cheat Sheet)$" } })
hl.window_rule({ tag = "+4ndr0666_Settings", match = { title = "^(4ndr0666 Hyprland Settings)$" } })
hl.window_rule({ tag = "+4ndr0666_Settings", match = { class = "^(nwg-displays|nwg-look)$" } })

-- terminal tags
hl.window_rule({ tag = "+terminal", match = { class = "^(Alacritty|kitty|kitty-dropterm)$" } })

-- email tags
hl.window_rule({ tag = "+email", match = { class = "^([Tt]hunderbird|org.gnome.Evolution)$" } })
hl.window_rule({ tag = "+email", match = { class = "^(eu.betterbird.Betterbird)$" } })

-- project tags
hl.window_rule({ tag = "+projects", match = { class = "^(codium|codium-url-handler|VSCodium)$" } })
hl.window_rule({ tag = "+projects", match = { class = "^(VSCode|code|code-url-handler)$" } })
hl.window_rule({ tag = "+projects", match = { class = "^(jetbrains-.+)$" } })

-- screenshare tags
hl.window_rule({ tag = "+screenshare", match = { class = "^(com.obsproject.Studio)$" } })

-- IM tags
hl.window_rule({ tag = "+im", match = { class = "^([Dd]iscord|[Ww]ebCord|[Vv]esktop)$" } })
hl.window_rule({ tag = "+im", match = { class = "^([Ff]erdium)$" } })
hl.window_rule({ tag = "+im", match = { class = "^([Ww]hatsapp-for-linux)$" } })
hl.window_rule({ tag = "+im", match = { class = "^(ZapZap|com.rtosta.zapzap)$" } })
hl.window_rule({ tag = "+im", match = { class = "^(org.telegram.desktop|io.github.tdesktop_x64.TDesktop)$" } })
hl.window_rule({ tag = "+im", match = { class = "^(teams-for-linux)$" } })
hl.window_rule({ tag = "+im", match = { class = "^(im.riot.Riot|Element)$" } })

-- game tags
hl.window_rule({ tag = "+games", match = { class = "^(gamescope)$" } })
hl.window_rule({ tag = "+games", match = { class = "^(steam_app_\\d+)$" } })

-- gamestore tags
hl.window_rule({ tag = "+gamestore", match = { class = "^([Ss]team)$" } })
hl.window_rule({ tag = "+gamestore", match = { title = "^([Ll]utris)$" } })
hl.window_rule({ tag = "+gamestore", match = { class = "^(com.heroicgameslauncher.hgl)$" } })

-- file-manager tags
hl.window_rule({ tag = "+file-manager", match = { class = "^([Tt]hunar|org.gnome.Nautilus|[Pp]cmanfm-qt)$" } })
hl.window_rule({ tag = "+file-manager", match = { class = "^(app.drey.Warp)$" } })

-- wallpaper tags
hl.window_rule({ tag = "+wallpaper", match = { class = "^([Ww]aytrogen)$" } })

-- multimedia tags
hl.window_rule({ tag = "+multimedia", match = { class = "^([Aa]udacious)$" } })

-- multimedia-video tags
hl.window_rule({ tag = "+multimedia_video", match = { class = "^([Mm]pv|vlc)$" } })

-- settings tags
hl.window_rule({ tag = "+settings", match = { title = "^(ROG Control)$" } })
hl.window_rule({ tag = "+settings", match = { class = "^(wihotspot(-gui)?)$" } })
hl.window_rule({ tag = "+settings", match = { class = "^([Bb]aobab|org.gnome.[Bb]aobab)$" } })
hl.window_rule({ tag = "+settings", match = { class = "^(gnome-disks|wihotspot(-gui)?)$" } })
hl.window_rule({ tag = "+settings", match = { title = "(Kvantum Manager)" } })
hl.window_rule({ tag = "+settings", match = { class = "^(file-roller|org.gnome.FileRoller)$" } })
hl.window_rule({ tag = "+settings", match = { class = "^(nm-applet|nm-connection-editor|blueman-manager)$" } })
hl.window_rule({ tag = "+settings", match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$" } })
hl.window_rule({ tag = "+settings", match = { class = "^(qt5ct|qt6ct|[Yy]ad)$" } })
hl.window_rule({ tag = "+settings", match = { class = "(xdg-desktop-portal-gtk)" } })
hl.window_rule({ tag = "+settings", match = { class = "^(org.kde.polkit-kde-authentication-agent-1)$" } })
hl.window_rule({ tag = "+settings", match = { class = "^([Rr]ofi)$" } })

-- viewer tags
hl.window_rule({ tag = "+viewer", match = { class = "^(gnome-system-monitor|org.gnome.SystemMonitor|io.missioncenter.MissionCenter)$" } })
hl.window_rule({ tag = "+viewer", match = { class = "^(evince)$" } })
hl.window_rule({ tag = "+viewer", match = { class = "^(eog|org.gnome.Loupe)$" } })

-- Some special override rules
hl.window_rule({ noblur = true, match = { tag = "multimedia_video*" } })
hl.window_rule({ opacity = 1.0, match = { tag = "multimedia_video*" } })

-- POSITION
hl.window_rule({ center = true, match = { tag = "4ndr0666_Cheat*" } })
hl.window_rule({ center = true, match = { class = "([Tt]hunar)", title = "negative:(.*[Tt]hunar.*)" } })
hl.window_rule({ center = true, match = { title = "^(ROG Control)$" } })
hl.window_rule({ center = true, match = { tag = "4ndr0666_Settings*" } })
hl.window_rule({ center = true, match = { title = "^(Keybindings)$" } })
hl.window_rule({ center = true, match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$" } })
hl.window_rule({ center = true, match = { class = "^([Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap)$" } })
hl.window_rule({ center = true, match = { class = "^([Ff]erdium)$" } })
hl.window_rule({ move = "72% 7%", match = { title = "^(Picture-in-Picture)$" } })

-- windowrule to avoid idle for fullscreen apps
hl.window_rule({ idleinhibit = "fullscreen", match = { fullscreen = 1 } })

-- FLOAT
hl.window_rule({ float = true, match = { tag = "4ndr0666_Cheat*" } })
hl.window_rule({ float = true, match = { tag = "wallpaper*" } })
hl.window_rule({ float = true, match = { tag = "settings*" } })
hl.window_rule({ float = true, match = { tag = "viewer*" } })
hl.window_rule({ float = true, match = { tag = "4ndr0666_Settings*" } })
hl.window_rule({ float = true, match = { class = "([Zz]oom|onedriver|onedriver-launcher)$" } })
hl.window_rule({ float = true, match = { class = "(org.gnome.Calculator)", title = "(Calculator)" } })
hl.window_rule({ float = true, match = { class = "^(mpv|com.github.rafostar.Clapper)$" } })
hl.window_rule({ float = true, match = { class = "^([Qq]alculate-gtk)$" } })
hl.window_rule({ float = true, match = { class = "^([Ff]erdium)$" } })
hl.window_rule({ float = true, match = { title = "^(Picture-in-Picture)$" } })

-- windowrule - float popups and dialogue
hl.window_rule({ float = true, match = { title = "^(Authentication Required)$" } })
hl.window_rule({ center = true, match = { title = "^(Authentication Required)$" } })
hl.window_rule({ float = true, match = { class = "(codium|codium-url-handler|VSCodium)", title = "negative:(.*codium.*|.*VSCodium.*)" } })
hl.window_rule({ float = true, match = { class = "^(com.heroicgameslauncher.hgl)$", title = "negative:(Heroic Games Launcher)" } })
hl.window_rule({ float = true, match = { class = "^([Ss]team)$", title = "negative:^([Ss]team)$" } })
hl.window_rule({ float = true, match = { class = "([Tt]hunar)", title = "negative:(.*[Tt]hunar.*)" } })

hl.window_rule({ float = true, match = { title = "^(Add Folder to Workspace)$" } })
hl.window_rule({ size = "70% 60%", match = { title = "^(Add Folder to Workspace)$" } })
hl.window_rule({ center = true, match = { title = "^(Add Folder to Workspace)$" } })

hl.window_rule({ float = true, match = { title = "^(Save As)$" } })
hl.window_rule({ size = "70% 60%", match = { title = "^(Save As)$" } })
hl.window_rule({ center = true, match = { title = "^(Save As)$" } })

hl.window_rule({ float = true, match = { initialTitle = "(Open Files)" } })
hl.window_rule({ size = "70% 60%", match = { initialTitle = "(Open Files)" } })

hl.window_rule({ float = true, match = { title = "^(SDDM Background)$" } })
hl.window_rule({ center = true, match = { title = "^(SDDM Background)$" } })
hl.window_rule({ size = "16% 12%", match = { title = "^(SDDM Background)$" } })

-- OPACITY
hl.window_rule({ opacity = "0.99 0.8", match = { tag = "browser*" } })
hl.window_rule({ opacity = "0.9 0.8", match = { tag = "projects*" } })
hl.window_rule({ opacity = "0.94 0.86", match = { tag = "im*" } })
hl.window_rule({ opacity = "0.94 0.86", match = { tag = "multimedia*" } })
hl.window_rule({ opacity = "0.9 0.8", match = { tag = "file-manager*" } })
hl.window_rule({ opacity = "0.9 0.7", match = { tag = "terminal*" } })
hl.window_rule({ opacity = "0.8 0.7", match = { tag = "settings*" } })
hl.window_rule({ opacity = "0.82 0.75", match = { tag = "viewer*" } })
hl.window_rule({ opacity = "0.9 0.7", match = { tag = "wallpaper*" } })
hl.window_rule({ opacity = "0.8 0.7", match = { class = "^(gedit|org.gnome.TextEditor|mousepad)$" } })
hl.window_rule({ opacity = "0.9 0.8", match = { class = "^(deluge)$" } })
hl.window_rule({ opacity = "0.9 0.8", match = { class = "^(seahorse)$" } })
hl.window_rule({ opacity = "0.95 0.75", match = { title = "^(Picture-in-Picture)$" } })

-- SIZE
hl.window_rule({ size = "65% 90%", match = { tag = "4ndr0666_Cheat*" } })
hl.window_rule({ size = "70% 70%", match = { tag = "wallpaper*" } })
hl.window_rule({ size = "70% 70%", match = { tag = "settings*" } })
hl.window_rule({ size = "60% 70%", match = { class = "^([Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap)$" } })
hl.window_rule({ size = "60% 70%", match = { class = "^([Ff]erdium)$" } })

-- PINNING
hl.window_rule({ pin = true, match = { title = "^(Picture-in-Picture)$" } })

-- extras
hl.window_rule({ keepaspectratio = true, match = { title = "^(Picture-in-Picture)$" } })

-- BLUR & FULLSCREEN
hl.window_rule({ noblur = true, match = { tag = "games*" } })
hl.window_rule({ fullscreen = true, match = { tag = "games*" } })

-- FOCUS
hl.window_rule({ noinitialfocus = true, match = { class = "^(jetbrains-*)" } })
hl.window_rule({ noinitialfocus = true, match = { title = "^(wind.*)$" } })

-- LAYER RULES
hl.layer_rule({ blur = true, match = { namespace = "rofi" } })
hl.layer_rule({ ignorezero = true, match = { namespace = "rofi" } })
hl.layer_rule({ blur = true, match = { namespace = "notifications" } })
hl.layer_rule({ ignorezero = true, match = { namespace = "notifications" } })
hl.layer_rule({ blur = true, match = { namespace = "quickshell:overview" } })
hl.layer_rule({ ignorezero = true, match = { namespace = "quickshell:overview" } })
hl.layer_rule({ ignorealpha = 0.5, match = { namespace = "quickshell:overview" } })
