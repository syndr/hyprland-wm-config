-- WEZTERM GLOBAL CONFIGURATION

local wezterm = require 'wezterm'
local config = wezterm.config_builder()
local act = wezterm.action

config.color_scheme = 'Snazzy'
config.window_background_opacity = 0.85
config.use_fancy_tab_bar = false
config.initial_cols = 140
config.initial_rows = 40

config.command_palette_bg_color = '#000000'
config.command_palette_fg_color = '#00FF00'
config.command_palette_font_size = 11.0
config.warn_about_missing_glyphs = false

config.colors = {
  foreground = '#27b182',
  background = '#000000',
  tab_bar = {
    background = '#041002',
    active_tab = {
      bg_color = '#0cd900',
      fg_color = '#000000',
      intensity = 'Normal',
      underline = 'None',
      italic = false,
      strikethrough = false,
    },
    inactive_tab = {
      bg_color = '#32852d',
      fg_color = '#0bbd00',
    },
    inactive_tab_hover = {
      bg_color = '#2db824',
      fg_color = '#3af765',
      italic = false,
    },
    new_tab = {
      bg_color = '#00ff3a',
      fg_color = '#005226',
    },
    new_tab_hover = {
      bg_color = '#00ffa5',
      fg_color = '#000000',
      italic = false,
    },
  },
}

config.font = wezterm.font 'VictorMono Nerd Font'
config.font_size = 10
config.cell_width = 0.9
config.harfbuzz_features = {
  'dlig=1',
  'calt=1',
  'clig=1',
}

config.keys = {
  { key = 'UpArrow', mods = 'SHIFT', action = act.ScrollByLine(-1) },
  { key = 'DownArrow', mods = 'SHIFT', action = act.ScrollByLine(1) },
}

config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = { WheelUp = 1 } } },
    mods = 'NONE',
    action = act.ScrollByLine(-1),
  },
  {
    event = { Down = { streak = 1, button = { WheelUp = 1 } } },
    mods = 'SHIFT',
    action = act.ScrollByLine(-5),
  },
  {
    event = { Down = { streak = 1, button = { WheelDown = 1 } } },
    mods = 'SHIFT',
    action = act.ScrollByLine(5),
  },
  {
    event = { Down = { streak = 1, button = { WheelDown = 1 } } },
    mods = 'NONE',
    action = act.ScrollByLine(1),
  },
  {
    event = { Down = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = wezterm.action.SelectTextAtMouseCursor 'Cell',
  },
  {
    event = { Down = { streak = 1, button = 'Left' } },
    mods = 'SHIFT',
    action = wezterm.action.ExtendSelectionToMouseCursor 'Cell',
  },
}

wezterm.on('rename-tab', function(window, pane)
  window:perform_action(
    wezterm.action.PromptInputLine {
      description = 'Enter new name for tab',
      action = wezterm.action_callback(function(inner_window, _, line)
        if line then
          inner_window:active_tab():set_title(line)
        end
      end),
    },
    pane
  )
end)

table.insert(config.keys, {
  key = 'r',
  mods = 'CTRL|SHIFT',
  action = wezterm.action.EmitEvent('rename-tab'),
})

return config
