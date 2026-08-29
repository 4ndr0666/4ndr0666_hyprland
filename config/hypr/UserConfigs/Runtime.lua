-- File: UserConfigs/Runtime.lua
-- Runtime-only Lua overrides for Hyprland 0.56.

local mainMod = "SUPER"

-- Replace the legacy keyword-based desktop zoom bindings from configs.Keybinds.lua.
hl.unbind(mainMod .. " + ALT + mouse_down")
hl.unbind(mainMod .. " + ALT + mouse_up")

local function adjust_cursor_zoom(factor)
    local zoom = hl.get_config("cursor.zoom_factor")
    if zoom < 1 then
        zoom = 1
    end
    hl.config({ cursor = { zoom_factor = zoom * factor } })
end

hl.bind(mainMod .. " + ALT + mouse_down", function()
    adjust_cursor_zoom(2.0)
end, { description = "zoom in" })

hl.bind(mainMod .. " + ALT + mouse_up", function()
    adjust_cursor_zoom(0.5)
end, { description = "zoom out" })
