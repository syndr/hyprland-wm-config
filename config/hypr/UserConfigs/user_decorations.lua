-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- User decorations overrides.

-- Greenscreen palette. Fixed colours rather than wallust-derived ones, so the
-- theme stays green whatever the wallpaper.
--
-- true: WallustSwww.sh and ThemeChanger.sh leave the border, shadow and group
-- colours below alone on wallpaper/theme changes. false: they follow the
-- wallpaper palette.
KOOLDOTS_FIXED_BORDER_COLORS = true

hl.config({
  general = {
    border_size = 2,
    gaps_in = 3,
    gaps_out = 5,
    col = {
      active_border = "rgb(4cff00)",
      inactive_border = "rgb(21ad42)",
    },
  },
})

hl.config({
  decoration = {
    rounding = 0,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    fullscreen_opacity = 1.0,
    dim_inactive = false,
    dim_strength = 0.05,
    dim_special = 0.8,
    shadow = {
      enabled = true,
      range = 10,
      render_power = 4,
      color = "rgb(21ad42)",
      color_inactive = "rgb(133100)",
    },
    blur = {
      enabled = true,
      size = 4,
      passes = 1,
      new_optimizations = true,
      xray = true,
      ignore_opacity = true,
      special = true,
      popups = true,
    },
  },
})

hl.config({
  group = {
    col = {
      border_active = "rgba(4cff00ee)",
      border_inactive = "rgba(21ad4280)",
      border_locked_active = "rgba(996600ee)",
      border_locked_inactive = "rgba(99660080)",
    },
    groupbar = {
      enabled = true,
      height = 18,
      render_titles = true,
      font_size = 12,
      gradients = true,
      text_color = "rgba(4cff00ff)",
      col = {
        active = "rgb(0d3b00)",
        inactive = "rgb(0a0a0a)",
        locked_active = "rgb(332200)",
        locked_inactive = "rgb(1a1000)",
      },
    },
  },
})
