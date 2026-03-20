# Changelog — JAK's Hyprland Dotfiles

## v2.4.0 — 2025-12-12 (Ultroncore Fork)

### 🎨 Greenscreen Theme
- New waybar config `[TOP] Greenscreen` with custom notification drawer
- Quick settings drawer: settings, terminal, file manager, browser, wallpaper, power, lock, idle inhibitor
- Calendar popup on clock with green-themed colors
- Pulseaudio format spacing fix
- Tooltip styling (black background, green border)
- Complete module color definitions for theme consistency

### 🔔 Notifications
- SwayNC: Notification sound support via pw-play

### 🪟 Window Rules
- Float rule for Feeling Finder (codes.merritt.FeelingFinder)

### 🖱️ Cursors
- Added Broodwar cursor theme

### ⚙️ Base Customizations (from PR #1)
- Custom UserSettings, UserKeybinds, UserAnimations, UserDecorations
- CopyQ configuration
- Wezterm configuration
- SwayNC styling updates
- Rofi configuration tweaks
- Hypridle adjustments
- WorkSpaceRules customizations

## v2.3.18 — 2025-11-05

- Keybinds: initialize SUPER+J/K at login to match the default layout (master or dwindle).
  - Adds scripts/KeybindsLayoutInit.sh and wires it to Startup_Apps so J/K and O (togglesplit) are correct on first session.
  - ChangeLayout.sh continues to rebind dynamically when layouts are toggled.
  - Credits: [Suresh Thagunna](https://github.com/suresh466) for identifying the mismatch and proposing an auto-alignment approach.
- Startup config sourcing: load vendor Startup_Apps and WindowRules first, then user overlays, restoring baseline autostarts while keeping user additions.
- Quick Settings: “Edit Startup Apps” opens the full vendor defaults for clarity.

## October 2025

### ⌨️ Keybinds

- Convert Hyprland keybinds to description form (`bindd`, `bindld`, `binded`,
  `bindmd`, `bindlnd`) in `config/hypr/...`.
- Add concise descriptions for each keybind; keep the name "powermenu".
- Update `config/hypr/scripts/KeyBinds.sh` to parse and display descriptions
  as: MODS+KEY — DESCRIPTION — DISPATCHER [PARAMS].

### 🐛 Fixes

- Updated `/bin/bash` to `/usr/bin/env bash`
- Correct `windowrule` syntax error.
- Ensure wallpaper selector applies wallpaper to SDDM.
- Update theme colors when a new wallpaper is selected.

### 🖥️ Jak dotfiles version now in `fastfetch` output.

### 🌦️ Weather.py

Key Changes:

- 2nd Weather.py Update by prabinpanta0
- ♻️ Substantial rewrite.
- ✨ New unified weather entrypoint (weatherWrap.sh)
  - With Python-first execution
- 🔒 Automatic weather updates before screen lock
- 🚀 Weather cache initialization at session startup
- 🛡️ Enhanced error handling and fallback mechanisms
- 📍 Automatic location detection via IP geolocation
- 🎨 Improved weather condition mapping and JSON output

### 🖥️ Support for debian and ubuntu installs

- Providing they are using Hyprland 0.51.1 or greater

### 🖥️ Drop-down terminal

- 🔧 Start on login via `TerminalDropDown.sh` so first invocation works.
- 🐱 Use Kitty explicitly instead of `$TERM` for consistent behavior.

### 🌇 HyprSunset

- 🔧 Availble from waybar or`SUPER + N`

### 🖱️ Gestures

- 🔧 Updated to accommodate Hyprland 0.5x changes.

### 👥 Contributors

- [prabinpanta0](https://github.com/prabinpanta0)
- [CharlyMH](https://github.com/CharlyMH)
- [ndeekshith](https://github.com/ndeekshith)
- [SherLock707](https://github.com/SherLock707)
- [SVIGHNESH](https://github.com/SVIGHNESH)

If you have any questions, feel free to contact via [GitHub Discussions](https://github.com/syndr/hyprland-wm-config/discussions) or the upstream project's [Discord Server](https://discord.gg/kool-tech-world)
