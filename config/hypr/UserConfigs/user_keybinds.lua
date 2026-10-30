-- User keybind overrides.
-- Add, override, or rebind keybinds here.
--
-- =============================================================================
-- KEYBIND RULES & SYNTAX
-- =============================================================================
-- • bind("MODS", "KEY", action, [options])
-- • unbind("MODS", "KEY")
--
-- Supported modifiers:
--   "SUPER", "SHIFT", "CTRL", "ALT", or combinations like "SUPER SHIFT", "SUPER ALT"
--
-- Actions:
--   • exec_cmd("command")       -> launches a terminal command or script
--   • dispatch("dispatcher", [arg]) -> triggers a Hyprland dispatcher (e.g. killactive, togglefloating)
--
-- =============================================================================
-- EXAMPLES
-- =============================================================================
--
-- NOTE ON LUA REBINDS:
--   Yes — same rule as Hyprlang applies in practice: if a key combo is already bound,
--   unbind("MODS", "KEY") first, then bind(...) it to the new action.
--   This keeps behavior explicit and avoids duplicate/conflicting binds.
--
-- 1. ADDING A BRAND NEW KEYBIND (combo not used by default):
--    bind("SUPER", "Z", exec_cmd("ghostty"), { description = "Launch Ghostty" })
--    bind("SUPER SHIFT", "V", exec_cmd("pavucontrol"), { description = "Audio Control" })
--    bind("SUPER", "X", dispatch("killactive"), { description = "Close active window" })
--
-- 2. OVERRIDING AN EXISTING COMBO WITH A DIFFERENT APP/COMMAND:
--    -- To replace what SUPER+Return opens (default: kitty):
--    unbind("SUPER", "Return")
--    bind("SUPER", "Return", exec_cmd("ghostty"), { description = "Launch Ghostty" })
--
-- 3. REBINDING / MOVING AN ACTION TO A NEW KEY COMBINATION:
--    -- Example: Move File Manager from SUPER+E to SUPER+F, and use SUPER+E for Emacs:
--    unbind("SUPER", "E")       -- unbind default file manager from SUPER+E
--    unbind("SUPER", "F")       -- unbind whatever SUPER+F was doing (default: fake fullscreen)
--    bind("SUPER", "F", exec_cmd("$HOME/.config/hypr/scripts/LaunchFileManager.sh '$files' '$term'"), { description = "File manager" })
--    bind("SUPER", "E", exec_cmd("emacsclient -c -a 'emacs'"), { description = "Launch Emacs" })
--
-- 4. REBINDING COMPOSITOR DISPATCHERS (e.g. workspace, fullscreen, floating):
--    unbind("SUPER", "Q")
--    bind("SUPER", "Q", dispatch("killactive"), { description = "Close active window" })
--    unbind("SUPER", "F") -- default fakefullscreen
--    bind("SUPER SHIFT", "F", dispatch("fullscreen", "0"), { description = "Toggle fullscreen" })
--    bind("SUPER ALT", "W", dispatch("workspace", "special:scratchpad"), { description = "Toggle scratchpad" })
--
-- 5. BIND OPTIONS (locked, repeating):
--    -- locked = true     -> runs even when lockscreen is active (e.g. media keys)
--    -- repeating = true  -> repeats when key is held down (e.g. volume / brightness)
--    bind("CTRL ALT", "bracketright", exec_cmd("$HOME/.config/hypr/scripts/Brightness.sh --inc"), { description = "Brightness up", repeating = true })
--    bind("", "XF86AudioMute", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --toggle"), { description = "Mute audio", locked = true })
--
-- =============================================================================
local user_keybinds_helper = nil
local submap_helper = nil
do
  local source = (debug.getinfo(1, "S") or {}).source or ""
  local source_path = source:match("^@(.+)$")
  local source_dir = source_path and source_path:match("^(.*)/[^/]+$") or nil
  local home = os.getenv("HOME") or ""

  -- Load a helper module from the first candidate path that defines what we
  -- expect. Each helper is loaded exactly once, so a local copy always wins
  -- over the shipped template and no module is executed twice.
  local function load_helper(file_name, validate)
    local candidate_paths = {
      source_dir and (source_dir .. "/../lua/" .. file_name) or nil,
      home ~= "" and (home .. "/.config/hypr/lua/" .. file_name) or nil,
      home ~= "" and (home .. "/.config/hypr/" .. file_name) or nil,
    }

    local tried_paths = {}
    for _, helper_path in ipairs(candidate_paths) do
      if helper_path then
        table.insert(tried_paths, helper_path)
        local f = io.open(helper_path, "r")
        if f then
          f:close()
          local loaded_ok, loaded_helpers = pcall(dofile, helper_path)
          if loaded_ok and type(loaded_helpers) == "table" and validate(loaded_helpers) then
            return loaded_helpers
          end
        end
      end
    end

    return nil, tried_paths
  end

  local tried_paths
  user_keybinds_helper, tried_paths = load_helper("user_keybinds_helper.lua", function(helpers)
    return helpers.bind ~= nil
  end)
  if not user_keybinds_helper then
    error("Failed to load user_keybinds_helper.lua from: " .. table.concat(tried_paths or {}, ", "))
  end

  -- submap_helper is optional: a missing or broken file must not take down all
  -- user keybinds, so it degrades to a warning and the keybinds below still load.
  submap_helper = load_helper("submap_helper.lua", function(helpers)
    return helpers.submap ~= nil
  end)
end

local exec_cmd = user_keybinds_helper.exec_cmd
local dispatch = user_keybinds_helper.dispatch
local bind = user_keybinds_helper.bind
local unbind = user_keybinds_helper.unbind
local submap = submap_helper and submap_helper.submap or nil
if not submap then
  print("[WARN] submap_helper.lua was not found; the submap.* helpers are unavailable. "
    .. "Copy config/hypr/lua/submap_helper.lua to ~/.config/hypr/lua/ to enable them.")
end

-- =============================================================================
-- DISPLAY LAYOUTS
-- =============================================================================
-- SUPER+ALT+D opens the layout menu for the monitor set in front of you.
-- SUPER+ALT+W applies a layout named Work directly, which is also the fallback
-- for when rofi will not start. Both combos were free: SUPER+ALT+H and
-- SUPER+ALT+P are taken by "horizontal scroll right" and the KB-passthrough
-- submap.
bind(
  "SUPER ALT",
  "D",
  exec_cmd("$HOME/.config/hypr/scripts/DisplayProfileMenu.sh"),
  { description = "Display layouts: menu for this monitor set" }
)
bind(
  "SUPER ALT",
  "W",
  -- A bare layout name is the controller's "apply this layout" verb, passed
  -- after -- so a name that looks like an option stays data. Create a layout
  -- called Work (menu -> Edit parameters) and this key applies it.
  exec_cmd("$HOME/.config/hypr/scripts/DisplayProfile.sh -- Work"),
  { description = "Display layouts: apply the layout named Work" }
)

-- =============================================================================
-- FORK KEYBINDS
-- =============================================================================
local scriptsDir = "$HOME/.config/hypr/scripts"
local userScripts = "$HOME/.config/hypr/UserScripts"

-- Vendor binds Alt+Shift (either order, either side) to keyboard-layout
-- switching, which fires on ordinary Alt+Shift chords. Set true if you use
-- more than one keyboard layout.
local KB_LAYOUT_SWITCH_KEYS = false
if not KB_LAYOUT_SWITCH_KEYS then
  unbind("ALT", "Shift_L")
  unbind("ALT", "Shift_R")
  unbind("SHIFT", "Alt_L")
  unbind("SHIFT", "Alt_R")
end

unbind("SUPER", "R")
bind("SUPER", "R", exec_cmd(scriptsDir .. "/RofiLauncherMenu.sh"), { description = "launcher menu" })
-- Scrolling column width, stepped through scrolling:explicit_column_widths
-- (user_settings.lua). Replaces vendor's SUPER R cycle, which only goes one
-- way through a coarse list. Hold to repeat.
bind("SUPER SHIFT", "R", hl.dsp.layout("colresize +conf"), { description = "Column width up (scrolling)", repeating = true })
bind("SUPER ALT SHIFT", "R", hl.dsp.layout("colresize -conf"), { description = "Column width down (scrolling)", repeating = true })

-- Scrolling layout on two macro-pad knobs, set to send F13-F18 (e.g. via VIA).
-- The us layout maps those keys to XF86Tools and XF86Launch5-9.
--   pan knob:   F13 / F14 turn, F15 press
--   width knob: F16 / F17 turn, F18 press
local KNOB_PAN_PX = 200
bind("", "XF86Tools", hl.dsp.layout("move -" .. KNOB_PAN_PX), { description = "Knob: pan view back (scrolling)" })
bind("", "XF86Launch5", hl.dsp.layout("move +" .. KNOB_PAN_PX), { description = "Knob: pan view forward (scrolling)" })
bind("", "XF86Launch6", hl.dsp.layout("fit active"), { description = "Knob: center active column (scrolling)" })
bind("", "XF86Launch7", hl.dsp.layout("colresize -conf"), { description = "Knob: column width down (scrolling)" })
bind("", "XF86Launch8", hl.dsp.layout("colresize +conf"), { description = "Knob: column width up (scrolling)" })
-- Toggles per workspace: fit every column on screen, then back to 1/3 widths.
local knob_fit_all = {}
bind("", "XF86Launch9", function()
  local ws = hl.get_active_workspace and hl.get_active_workspace()
  local id = ws and ws.id or 0
  local msg = knob_fit_all[id] and "colresize all 0.333" or "fit all"
  pcall(hl.dispatch, hl.dsp.layout(msg))
  knob_fit_all[id] = not knob_fit_all[id]
end, { description = "Knob: fit all columns / back to 1/3 (scrolling)" })
bind("SUPER", "BackSpace", exec_cmd("pkill rofi || true && rofi -show drun -modi drun,filebrowser,run,window"), { description = "app launcher" })
bind("SUPER", "grave", exec_cmd(scriptsDir .. "/LockScreen.sh"), { description = "lock screen" })
bind("SUPER SHIFT", "L", exec_cmd(userScripts .. "/ScreenHackSelect.sh"), { description = "screensaver hack picker" })

-- Filtered window switcher: hides special-workspace windows (dropdown
-- terminal scratchpad, xwaylandvideobridge).
unbind("SUPER CTRL", "S")
bind("SUPER CTRL", "S", exec_cmd("pkill rofi || true && " .. userScripts .. "/WindowSwitcher.sh"), { description = "window switcher" })

bind("SUPER", "bracketleft", dispatch("layoutmsg", "orientationprev"), { description = "orientation prev" })
bind("SUPER", "bracketright", dispatch("layoutmsg", "orientationnext"), { description = "orientation next" })
bind("SUPER", "V", exec_cmd("copyq toggle"), { description = "copyq toggle" })

bind("SUPER ALT", "Print", exec_cmd(scriptsDir .. "/ScreenShot.sh --area-in5"), { description = "delayed screenshot (area in 5s)" })
bind("SUPER ALT", "X", exec_cmd(scriptsDir .. "/ScreenShot.sh --monitor-in5"), { description = "delayed screenshot (focused monitor in 5s)" })

bind("SUPER CTRL SHIFT", "F9", dispatch("movecurrentworkspacetomonitor", "l"), { description = "move workspace to left monitor" })
bind("SUPER CTRL SHIFT", "F10", dispatch("movecurrentworkspacetomonitor", "r"), { description = "move workspace to right monitor" })
bind("SUPER CTRL SHIFT", "F11", dispatch("movecurrentworkspacetomonitor", "u"), { description = "move workspace to up monitor" })
bind("SUPER CTRL SHIFT", "F12", dispatch("movecurrentworkspacetomonitor", "d"), { description = "move workspace to down monitor" })

bind("", "mouse:277", exec_cmd(scriptsDir .. "/WorkspaceCycle.sh prev"), { description = "previous workspace on current monitor" })
bind("", "mouse:278", exec_cmd(scriptsDir .. "/WorkspaceCycle.sh next"), { description = "next workspace on current monitor" })
bind("", "mouse:279", exec_cmd(scriptsDir .. "/OverviewToggle.sh"), { description = "desktop overview", release = true })

-- Desktop zoom (SUPER ALT + scroll). Hyprland passes wheel events inside
-- binds:scroll_event_delay through to the focused window, so a hi-res wheel
-- scrolls the page while zooming; user_settings.lua sets the delay to 0 and
-- binds that want a slower cadence wrap themselves in WheelThrottle.sh.
-- Horizontal wheel is swallowed so sideways drift does not scroll the window.
-- Step size lives in scripts/Zoom.sh.
unbind("SUPER ALT", "mouse_down")
unbind("SUPER ALT", "mouse_up")
bind("SUPER ALT", "mouse_down", exec_cmd(scriptsDir .. "/Zoom.sh in"), { description = "zoom in" })
bind("SUPER ALT", "mouse_up", exec_cmd(scriptsDir .. "/Zoom.sh out"), { description = "zoom out" })
bind("SUPER ALT", "mouse_left", hl.dsp.no_op(), { description = "swallow horizontal wheel while zooming" })
bind("SUPER ALT", "mouse_right", hl.dsp.no_op(), { description = "swallow horizontal wheel while zooming" })
bind("SUPER ALT", "0", exec_cmd(scriptsDir .. "/Zoom.sh reset"), { description = "reset zoom" })

-- Zoom mode: hands-free variant. SUPER ALT Z to enter, scroll to zoom, 0 to
-- reset, Escape or SUPER ALT Z to exit.
bind("SUPER ALT", "Z", hl.dsp.submap("zoom"), { description = "enter zoom mode" })
hl.define_submap("zoom", function()
  bind("", "mouse_down", exec_cmd(scriptsDir .. "/Zoom.sh in"), { description = "zoom in" })
  bind("", "mouse_up", exec_cmd(scriptsDir .. "/Zoom.sh out"), { description = "zoom out" })
  bind("", "mouse_left", hl.dsp.no_op(), { description = "swallow horizontal wheel" })
  bind("", "mouse_right", hl.dsp.no_op(), { description = "swallow horizontal wheel" })
  bind("", "0", exec_cmd(scriptsDir .. "/Zoom.sh reset"), { description = "reset zoom" })
  bind("", "escape", hl.dsp.submap("reset"), { description = "exit zoom mode" })
  bind("SUPER ALT", "Z", hl.dsp.submap("reset"), { description = "exit zoom mode" })
end)

-- Workspace wheel, throttled: scroll_event_delay is 0 for the zoom binds.
unbind("SUPER", "mouse_down")
unbind("SUPER", "mouse_up")
bind("SUPER", "mouse_down", exec_cmd(scriptsDir .. "/WheelThrottle.sh ws 300 \"hl.dsp.focus({ workspace = 'e+1' })\""), { description = "next workspace" })
bind("SUPER", "mouse_up", exec_cmd(scriptsDir .. "/WheelThrottle.sh ws 300 \"hl.dsp.focus({ workspace = 'e-1' })\""), { description = "previous workspace" })

-- Per-machine overlay (e.g. monitor-specific workspace maps). Not shipped;
-- the installer preserves it across upgrades.
do
  local overlay = (os.getenv("HOME") or "") .. "/.config/hypr/UserConfigs/user_workspace_keybinds.lua"
  local f = io.open(overlay, "r")
  if f then
    f:close()
    local ok, err = pcall(dofile, overlay)
    if not ok then
      print("[WARN] user_keybinds: " .. overlay .. ": " .. tostring(err))
    end
  end
end

-- After the overlay: a workspace map that unbinds the number row must not
-- take these with it.
unbind("SUPER", "5")
unbind("SUPER", "6")
bind("SUPER", "5", hl.dsp.focus({ monitor = "+1" }), { description = "focus monitor right" })
bind("SUPER", "6", hl.dsp.focus({ monitor = "-1" }), { description = "focus monitor left" })
