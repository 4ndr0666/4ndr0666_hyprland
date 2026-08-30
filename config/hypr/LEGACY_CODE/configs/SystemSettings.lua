-- File: configs/SystemSettings.lua
-- /* ---- 💫 https://github.com/4ndr0666 💫 ---- */  #
-- Default settings

local scriptsDir = os.getenv("HOME") .. "/.config/hypr/scripts"

hl.config({
    dwindle = {
        preserve_split = true,
        special_scale_factor = 0.8,
    },
    master = {
        mfact = 0.65,
        new_status = "slave",
        new_on_top = true,
        orientation = "left",
        slave_count_for_center_master = 2,
        center_master_fallback = "left",
        smart_resizing = true,
    },
    general = {
        resize_on_border = true,
        layout = "dwindle",
    },
    input = {
        kb_layout = "us",
        kb_variant = "",
        kb_model = "pc105",
        kb_options = "",
        kb_rules = "evdev",
        repeat_rate = 50,
        repeat_delay = 300,
        sensitivity = 0,
        numlock_by_default = true,
        left_handed = false,
        follow_mouse = 1,
        float_switch_override_focus = false,
        touchpad = {
            disable_while_typing = true,
            natural_scroll = true,
            clickfinger_behavior = false,
            middle_button_emulation = false,
            tap_to_click = true,
            drag_lock = false,
        },
        touchdevice = {
            enabled = true,
        },
        tablet = {
            transform = 0,
            left_handed = 0,
        },
    },
    gestures = {
        workspace_swipe_distance = 500,
        workspace_swipe_invert = true,
        workspace_swipe_min_speed_to_force = 30,
        workspace_swipe_cancel_ratio = 0.5,
        workspace_swipe_create_new = true,
        workspace_swipe_forever = true,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        vrr = 2,
        mouse_move_enables_dpms = true,
        enable_swallow = false,
        swallow_regex = "^(kitty)$",
        focus_on_activate = false,
        initial_workspace_tracking = 0,
        middle_click_paste = false,
        enable_anr_dialog = true,
        anr_missed_pings = 15,
        allow_session_lock_restore = true,
        on_focus_under_fullscreen = 1,
    },
    binds = {
        workspace_back_and_forth = true,
        allow_workspace_cycles = true,
        pass_mouse_when_bound = false,
    },
    xwayland = {
        enabled = true,
        force_zero_scaling = true,
    },
    render = {
        direct_scanout = 0,
    },
    cursor = {
        sync_gsettings_theme = true,
        no_hardware_cursors = 2,
        enable_hyprcursor = true,
        warp_on_change_workspace = 2,
        no_warps = true,
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.on("hyprland.start", function ()
    hl.exec_cmd("hyprctl keyword gesture '4, up, dispatcher, exec, hyprctl keyword cursor:zoom_factor \"$(hyprctl getoption cursor:zoom_factor | awk '\\''NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor * 1.5}'\\'')\"'")
    hl.exec_cmd("hyprctl keyword gesture '4, down, dispatcher, exec, hyprctl keyword cursor:zoom_factor \"$(hyprctl getoption cursor:zoom_factor | awk '\\''NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor / 1.5}'\\'')\"'")
    hl.exec_cmd("hyprctl keyword gesture '3, up, dispatcher, exec, " .. scriptsDir .. "/OverviewToggle.sh'")
end)
