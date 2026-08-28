-- File: UserConfigs/01-UserDefaults.lua
-- /* ---- 💫 https://github.com/4ndr0666 💫 ---- */  #
-- User Defaults: Default apps, search engine, etc.

-- Default editor
hl.env("EDITOR", "nvim")

-- Variable assignments
local term = "kitty"
local files = "thunar"
local search_engine = "https://www.yandex.com/search?text={}"

-- Expose defaults to the global Lua environment so other modules (like Keybinds.lua) can inherit them
_G.user_defaults = {
    term = term,
    files = files,
    search_engine = search_engine,
    editor = os.getenv("EDITOR") or "micro" -- Fallback to micro if EDITOR env is empty
}
-- Segment 1