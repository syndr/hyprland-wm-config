-- WEZTERM GLOBAL CONFIGURATION


-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

-- Runtime actions
local act = wezterm.action

-- Set the visual appearance
config.color_scheme = 'Snazzy'
config.window_background_opacity = 0.85
config.use_fancy_tab_bar = false
config.initial_cols = 140  -- Set the default width (columns)
config.initial_rows = 40   -- Set the default height (rows)

-- Theme the Command Palette (Launcher)
-- The background of the palette window
config.command_palette_bg_color = '#000000'
-- The default foreground color for prompts and unselected items
config.command_palette_fg_color = '#00FF00'

-- Font used in the palette window (needs nightly build)
--config.command_palette_font = wezterm.font 'IosevkaTerm NF'
config.command_palette_font_size = 11.0

-- Stop annoying alerts about missing glyphs in the font
config.warn_about_missing_glyphs = false

config.colors = {
  -- The default text color
  foreground = '#27b182',
  -- The default background color (black)
  background = '#000000',

  tab_bar = {
    -- The color of the strip that goes along the top of the window
    -- (does not apply when fancy tab bar is in use)
    background = '#0b0022',

    -- The active tab is the one that has focus in the window
    active_tab = {
      -- The color of the background area for the tab
      bg_color = '#0cd900',
      -- The color of the text for the tab
      fg_color = '#000000',

      -- Specify whether you want "Half", "Normal" or "Bold" intensity for the
      -- label shown for this tab.
      -- The default is "Normal"
      intensity = 'Normal',

      -- Specify whether you want "None", "Single" or "Double" underline for
      -- label shown for this tab.
      -- The default is "None"
      underline = 'None',

      -- Specify whether you want the text to be italic (true) or not (false)
      -- for this tab.  The default is false.
      italic = false,

      -- Specify whether you want the text to be rendered with strikethrough (true)
      -- or not for this tab.  The default is false.
      strikethrough = false,
    },

    -- Inactive tabs are the tabs that do not have focus
    inactive_tab = {
      bg_color = '#32852d',
      fg_color = '#0bbd00',

      -- The same options that were listed under the `active_tab` section above
      -- can also be used for `inactive_tab`.
    },

    -- You can configure some alternate styling when the mouse pointer
    -- moves over inactive tabs
    inactive_tab_hover = {
      bg_color = '#2db824',
      fg_color = '#3af765',
      italic = false,

      -- The same options that were listed under the `active_tab` section above
      -- can also be used for `inactive_tab_hover`.
    },

    -- The new tab button that let you create new tabs
    new_tab = {
      bg_color = '#00ff3a',
      fg_color = '#005226',

      -- The same options that were listed under the `active_tab` section above
      -- can also be used for `new_tab`.
    },

    -- You can configure some alternate styling when the mouse pointer
    -- moves over the new tab button
    new_tab_hover = {
      bg_color = '#00ffa5',
      fg_color = '#000000',
      italic = false,

      -- The same options that were listed under the `active_tab` section above
      -- can also be used for `new_tab_hover`.
    },
  },
}

-- Font options
config.font = wezterm.font 'VictorMono Nerd Font'
config.font_size = 10
config.cell_width = 0.9
config.harfbuzz_features = {
	"dlig=1", -- Ligatures
  "calt=1",
  "clig=1"
}

-- Keybindings
config.keys = {
  { key = 'UpArrow', mods = 'SHIFT', action = act.ScrollByLine(-1) },
  { key = 'DownArrow', mods = 'SHIFT', action = act.ScrollByLine(1) },
}

-- Mouse bindings
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

    -- Prevent selecting the full line on a normal left click
  {
    event = { Down = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = wezterm.action.SelectTextAtMouseCursor 'Cell', -- Select just the character
  },
  -- Hold Shift to select text from cursor position instead of the full line
  {
    event = { Down = { streak = 1, button = 'Left' } },
    mods = 'SHIFT',
    action = wezterm.action.ExtendSelectionToMouseCursor 'Cell', -- Allows custom selection
  },
}

-- Tab configuration
wezterm.on("rename-tab", function(window, pane)
  window:perform_action(
    wezterm.action.PromptInputLine {
      description = "Enter new name for tab",
      action = wezterm.action_callback(function(window, pane, line)
        if line then
          window:active_tab():set_title(line)
        end
      end),
    },
    pane
  )
end)

-- Add the rename-tab keybinding to existing keybindings
table.insert(config.keys, {
  key = "r",
  mods = "CTRL|SHIFT",
  action = wezterm.action.EmitEvent("rename-tab"),
})

-- and finally, return the configuration to wezterm
return config
