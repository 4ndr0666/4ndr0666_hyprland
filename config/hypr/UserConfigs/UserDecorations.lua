-- File: UserConfigs/UserDecorations.lua
-- /* ----  https://github.com/4ndr0666  ---- */  #
-- Decoration Settings

local home = os.getenv("HOME")
local wallust_colors = {}
local color_file = io.open(home .. "/.config/hypr/wallust/wallust-hyprland.conf", "r")
if color_file then
    for line in color_file:lines() do
        local key, val = line:match("%$(%w+)%s*=%s*(.+)")
        if key and val then
            wallust_colors[key] = val
        end
    end
    color_file:close()
end

local c12 = wallust_colors["color12"] or "rgba(33ccffee)"
local c10 = wallust_colors["color10"] or "rgba(595959aa)"
local c15 = wallust_colors["color15"] or "rgba(ffffffee)"
local c0  = wallust_colors["color0"]  or "rgba(000000aa)"

hl.config({
    general = {
        border_size = 2,
        gaps_in = 2,
        gaps_out = 4,
        ["col.active_border"] = c12,
        ["col.inactive_border"] = c10,
    },
    decoration = {
        rounding = 10,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        fullscreen_opacity = 1.0,
        dim_inactive = false,
        dim_strength = 0.1,
        dim_special = 0.8,
        shadow = {
            enabled = true,
            range = 3,
            render_power = 1,
            color = c12,
            color_inactive = c10,
        },
        blur = {
            enabled = true,
            size = 6,
            passes = 3,
            new_optimizations = true,
            xray = true,
            ignore_opacity = true,
            special = true,
            popups = true,
        },
    },
    group = {
        ["col.border_active"] = c15,
        groupbar = {
            ["col.active"] = c0,
        },
    },
})
-- Segment 1
