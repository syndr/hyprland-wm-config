-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- User environment overrides template.
-- Keep this file for personal env additions that should survive updates.

-- Examples:
-- hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
-- hl.env("GDK_SCALE", "1")
-- hl.env("QT_SCALE_FACTOR", "1")
-- hl.env("WEATHER_UNITS", "metric")

-- Fork theming: Kvantum is the Qt widget style (matches qt6ct style=kvantum).
-- The Hackerer Kvantum theme is optional: https://github.com/syndr/hackerer-theme
hl.env("QT_STYLE_OVERRIDE", "kvantum")
-- QT_QUICK_CONTROLS_STYLE is left to the installer's autodetect
-- (system_env.lua). org.hyprland.style would break Qt-Quick Flatpak apps, so
-- scripts/FlatpakThemeSync.sh strips it at the sandbox boundary instead; rerun
-- that script if Flatpak is installed after these dotfiles.
-- broodwar cursor (Hackerer theme).
hl.env("HYPRCURSOR_THEME", "broodwar")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "broodwar")
hl.env("XCURSOR_SIZE", "24")
hl.env("EDITOR", "nvim")
