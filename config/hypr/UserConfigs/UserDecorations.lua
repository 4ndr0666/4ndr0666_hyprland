-- File: UserConfigs/UserDecorations.lua
-- /* ----  https://github.com/4ndr0666  ---- */  #
-- Decoration Settings

local home = os.getenv("HOME")
local color_file_path = home .. "/.config/hypr/wallust/wallust-hyprland.conf"
local color_file = assert(io.open(color_file_path, "r"), "Wallust color provider is unavailable: " .. color_file_path)

local wallust_colors = {}
for line in color_file:lines() do
    local key, val = line:match("%$(%w+)%s*=%s*(.+)")
    if key and val then
        wallust_colors[key] = val
    end
end
color_file:close()

local required_colors = { "color0", "color10", "color12", "color15" }
for _, key in ipairs(required_colors) do
    assert(wallust_colors[key], "Wallust color provider is incomplete: missing " .. key)
end

local c12 = wallust_colors["color12"]
local c10 = wallust_colors["color10"]
local c15 = wallust_colors["color15"]
local c0  = wallust_colors["color0"]

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
