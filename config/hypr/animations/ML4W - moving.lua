-- File: animations/ML4W - moving.lua
-- /* ----  https://github.com/4ndr0666  ---- */
-- name "Moving"
-- credit https://github.com/mylinuxforwork/dotfiles

hl.config({ animations = { enabled = true } })
hl.curve("overshot", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("smoothOut", { type = "bezier", points = { {0.5, 0}, {0.99, 0.99} } })
hl.curve("smoothIn", { type = "bezier", points = { {0.5, -0.5}, {0.68, 1.5} } })
hl.animation({ leaf = "windows", enabled = true, speed = 5, curve = "overshot", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, curve = "smoothOut" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, curve = "smoothOut" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, curve = "smoothIn", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 5, curve = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, curve = "smoothIn" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 5, curve = "smoothIn" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, curve = "default" })
