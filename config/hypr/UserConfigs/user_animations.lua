-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- User animation overrides template.
-- Use this to override defaults from lua/animations.lua.

-- Example:
-- hl.config({
--   animations = {
--     enabled = true,
--   },
-- })
--
-- hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "wind", style = "slide" })

-- Curves are defined here as well: an animation preset from the Animations menu
-- replaces lua/animations.lua and need not define them.
hl.curve("winIn", { type = "bezier", points = { { 0.1, 1.1 }, { 0.1, 1.1 } } })
hl.curve("winOut", { type = "bezier", points = { { 0.3, -0.3 }, { 0, 1 } } })
hl.curve("smoothOut", { type = "bezier", points = { { 0.5, 0 }, { 0.99, 0.99 } } })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "winIn", style = "gnomed" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "smoothOut", style = "gnomed" })
-- borderangle drives rainbow borders; off with the fixed Greenscreen palette.
hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 5, bezier = "winIn", style = "slidevert" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 5, bezier = "winOut", style = "slidevert" })
