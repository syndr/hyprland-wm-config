-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- User settings overrides template.
-- Add your personal hl.config(...) values here.

hl.config({
  input = {
    kb_layout = "us",
    kb_variant = "",
    kb_model = "",
    kb_options = "",
    kb_rules = "",
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
})

-- Multi-language example:
-- NOTE: If specifying multiple layouts in kb_layout, kb_variant must have matching
-- comma separators (e.g. kb_layout = "fr,de", kb_variant = "azerty," or kb_variant = "").
--
-- hl.config({
--   input = {
--     kb_layout = "fr,de",
--     kb_variant = "azerty,",
--     kb_options = "grp:alt_shift_toggle",
--   },
--   misc = {
--     focus_on_activate = true,
--   },
-- })

-- Example:
-- hl.config({
--   general = {
--     gaps_in = 4,
--     gaps_out = 8,
--     border_size = 1,
--   },
-- })
--

-- Disable cursor being centered when swap workspaces
--
-- hl.config({
-- 	cursor = {
-- 		no_warps = true,
-- 		warp_on_change_workspace = 0,
-- 	},
-- })

-- Fork settings. Each block is applied separately so one key a given
-- Hyprland build does not know cannot drop the rest.
local function try_config(spec)
  local ok, err = pcall(hl.config, spec)
  if not ok then
    print("[WARN] user_settings: " .. tostring(err))
  end
end

try_config({ debug = { disable_logs = true } })
try_config({ dwindle = { split_width_multiplier = 1.5 } })
-- 2 = auto (software cursor only where the hardware cursor is known broken).
try_config({ cursor = { no_hardware_cursors = 2 } })
-- The zoom binds need every wheel event; see user_keybinds.lua.
try_config({ binds = { scroll_event_delay = 0 } })
