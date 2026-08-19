-- File: configs/ENVariables.lua
-- /* ----  https://github.com/4ndr0666  ---- */  #
-- Environment Variables

hl.env("DOTS_VERSION", "2.3.20")

-- Toolkit Backend Variables
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;wayland-egl;xcb")
hl.env("TDESKTOP_DISABLE_GTK_INTEGRATION", "1")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("BEMENU_BACKEND", "wayland")

-- Run SDL2 applications on Wayland.
-- Remove or set to x11 if games that provide older versions of SDL cause compatibility issues
-- hl.env("SDL_VIDEODRIVER", "wayland")

-- XDG Specifications
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_SESSION", "Hyprland")

-- QT Variables
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- Elementary environment
hl.env("ELM_DISPLAY", "wl")
hl.env("ECORE_EVAS_ENGINE", "wayland_egl")
hl.env("ELM_ENGINE", "wayland_egl")
hl.env("ELM_ACCEL", "opengl")

-- hyprland-qt-support
hl.env("QT_QUICK_CONTROLS_STYLE", "org.hyprland.style")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

-- xwayland apps scale fix
hl.env("GDK_SCALE", "1")
hl.env("QT_SCALE_FACTOR", "1")
hl.env("NO_AT_BRIDGE", "1")
hl.env("WINIT_UNIX_BACKEND", "wayland")

-- Bibata-Modern-Ice-Cursor
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")

-- electron >28 apps (may help)
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Firefox Wayland & Hardware Acceleration (Carried over from User Lua additions)
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("MOZ_DBUS_REMOTE", "1")
hl.env("MOZ_WAYLAND_USE_VAAPI", "1")
