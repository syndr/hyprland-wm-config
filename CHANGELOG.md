# Changelog — KoolDots

## Unreleased

## Changed

- **Idle/lock timeouts are now generated from
  `UserConfigs/IdleSettings.conf`.** `hypridle.conf` used to be six listeners
  of bare absolute seconds (15/570/600/605/1200/1800) that only made sense
  read together, and it was restored from backup on every upgrade — so edits
  survived but release fixes never landed. It is now a generated artifact
  (`scripts/GenerateHypridle.sh`) and `IdleSettings.conf` is the single tuning
  surface: named, relative, documented keys that the generator turns into the
  schedule. See
  [`docs/adr/generate-hypridle-config-from-idle-settings.md`](docs/adr/generate-hypridle-config-from-idle-settings.md).
  - Timeouts differ on battery and AC: `KOOL_IDLE_LOCK_TIMEOUT_AC` (900) /
    `_BAT` (300), `KOOL_IDLE_SCREENSAVER_AC` (1200) / `_BAT` (120),
    `KOOL_IDLE_DPMS_DELAY_AC` / `_BAT`, plus `KOOL_IDLE_WARN_LEAD`. hypridle
    cannot switch timeouts at runtime, so `IdlePowerWatch.sh` blocks on udev
    `power_supply` events and re-renders + reloads on plug/unplug — deferring
    the reload while the session is locked, since a restart resets idle timers.
  - A legacy un-suffixed `KOOL_IDLE_LOCK_TIMEOUT` still works and seeds both
    profiles. `KOOL_IDLE_MANAGED=0` opts out entirely and keeps the previous
    behavior (hand-owned file, legacy awk/sed rewrite, restore-from-backup).
  - On the first managed upgrade a hand-edited `hypridle.conf` is parked as
    `hypridle.conf.pre-managed` instead of being restored over the generated
    file; `run_post_upgrade_audit` warns if a stale file lands anyway.
- Waybar's `custom/hypridle` right-click now locks through `LockScreen.sh`
  instead of invoking `hyprlock` directly, which bypassed the swaylock-plugin
  screensaver.

## Added

- **The screensaver no longer burns power while the screen is off.**
  swaylock-plugin has no DPMS handling and forwards its plugin client's
  buffers straight through, so an xscreensaver hack running under Xwayland +
  `windowtolayer` is not frame-callback throttled — it kept rendering at full
  rate with the panel dark. `ScreenPower.sh` now fronts every DPMS transition
  this config drives and pairs it with `ScreensaverPause.sh`, which SIGSTOPs
  the hack's process group (SIGKILL would just trigger swaylock-plugin's
  auto-restart) and resumes it when the panel returns.
  - `ScreensaverPause.sh watch` also covers screen-off the compositor never
    sees — on the uConsole the power key parks the panel through
    `uconsole-sleep` while Hyprland still thinks its outputs are lit. It runs
    only while a locker is up. Knobs: `KOOL_IDLE_SCREENSAVER_PAUSE`,
    `..._PAUSE_WATCH`, `..._PAUSE_INTERVAL`.
- `Hypridle.sh reload` — restarts hypridle to pick up a regenerated config,
  and is deliberately a no-op when hypridle is stopped so it cannot undo the
  waybar idle-inhibit toggle.
- The xscreensaver hack-preview float rule, which existed only in
  `configs/WindowRules.conf`, now has its Lua equivalent in
  `lua/window_rules.lua`.
- `ScreenHackSelect.sh` fits the picker to the screen it opens on. The shipped
  theme asks for 9 rows of 88px thumbnails -- around 850px before chrome --
  which is taller than a small panel (the uConsole is 1280x720 logical), so
  the list was clipped top and bottom. The packaged picker hands the theme to
  rofi as `-config` and forwards nothing else, so the wrapper generates an
  overlay theme that imports the shipped one and overrides rows, thumbnail
  size and width for the focused output (rotation and scale accounted for).
  Knobs: `SCREENHACK_ROWS`, `SCREENHACK_ICON_SIZE`, `SCREENHACK_WIDTH_PCT`,
  and `SCREENHACK_NO_AUTOFIT=1` to keep the shipped theme unchanged.

## Fixed

- `copy.sh`: the picked screensaver hack was reset on every upgrade.
  `hypr/.swaylock_hack` (set via `SUPER SHIFT L`) sits directly in `hypr/`,
  which is replaced wholesale, and it was in no restore list -- so the choice
  silently reverted to the `xrayswarm` default each time. Now restored with
  the other per-install hypr state, express included.
- `copy.sh`: express upgrades could revert repo-owned `UserScripts`. Express
  rsyncs the whole backed-up `UserScripts/` over the fresh copy, so the
  packaged-tool wrappers (`ScreenHackSelect.sh`, `ScreenHackShots.sh`) would
  come back stale one release after any fix to them. They are now excluded
  from that restore; genuinely user-owned scripts are unaffected.

- `copy.sh`: upgrades wiped externally-installed theme payloads. `copy_phase2`
  replaces `qt5ct`/`qt6ct`/`Kvantum` wholesale, and the theme-state snapshot
  only preserved the top-level configs — so after an upgrade, `qt6ct.conf` and
  `kvantum.kvconfig` pointed at `Hackerer-Dark` color-scheme/theme files that
  no longer existed, silently reverting Qt apps to a default palette. The
  snapshot now also captures `qt5ct/colors`, `qt6ct/colors`, and `Kvantum/`
  and restores any files the new release doesn't ship (fill-in only, so
  repo-shipped scheme updates still land).
- Logout now goes through `Logout.sh` (the wlogout "logout" button and the
  `CTRL ALT Delete` keybind in `Keybinds.conf` previously ran
  `hyprctl dispatch exit 0` directly; the lua keybind already used it).
  Killing the compositor out from under its Wayland clients made the
  xdg-desktop-portal implementations, swaync, nm-applet, etc. die on a broken
  pipe as failed systemd user units, which fumon then reported as portal
  errors at the next login. `Logout.sh` shuts the session down via
  hyprshutdown/loginctl/uwsm so units are stopped cleanly first.
- `copy.sh`: every express upgrade (and any interactive run declining the
  Hackerer theme) silently aborted at the theme prompt — the function's
  "declined/skipped" return code tripped `set -e`, skipping the exec-bit
  pass, systemd user overrides, and waybar config normalization that follow.
  Symptom: scripts new in a release (e.g. `RofiLauncher.sh` after the layout
  refactor) deployed without exec bits, breaking the waybar app menu.
- Four layout-refactor scripts (`ChangeLayout.sh`, `RofiLauncher.sh`,
  `WorkspaceCycle.sh`, `WorkspacePicker.sh`) are now committed executable.

## Changed

- The three screensaver scripts (`SwaylockScreensaver.sh`,
  `ScreenHackSelect.sh`, `ScreenHackShots.sh`) are now thin wrappers around
  the packaged `swaylock-plugin-screensaver` tools (canonical source:
  swaylock-plugin `contrib/screensaver`, shipped by the phalanx image). The
  wrappers pin this config's state file, rofi theme, thumbnail cache, and
  hyprlock fallback; hosts without the package keep falling back to hyprlock.

## Added

- Screensaver lockscreen: `swaylock-plugin` with a live xscreensaver "hack"
  background replaces hyprlock when installed (hyprlock remains the automatic
  fallback on hosts without it)
  - `SUPER SHIFT L` rofi picker to choose the hack (`Alt+P` live preview,
    `. random` entry); choice persists to `~/.config/hypr/.swaylock_hack`
  - hypridle DPMS listeners now give the screensaver a 20-minute window after
    lock before screens power off (hyprlock keeps its quick-off behavior)
  - `IdleWatchdog.sh` and the installer's idle-policy rewrite are
    swaylock-aware
  - Recovery from a misbehaving locker: TTY → `killall swaylock-plugin` lands
    in hyprlock (fail-secure), see README
  - Hack previews float centered at half the monitor size (title-matched
    windowrule; the X class is per-hack so the title is the stable handle);
    the picker stays closed while a preview runs and reopens when the preview
    window is closed
  - Picker rows show each hack's screenshot and one-line description (both
    searchable): thumbnails are generated locally by
    `UserScripts/ScreenHackShots.sh` (headless Xvfb + ImageMagick capture,
    auto-kicked in the background on first picker use), descriptions come
    from the xscreensaver config XMLs
  - Fallback background: a hack that dies degrades to its generated
    screenshot (`--image`) instead of swaylock's blank gray
    (`SWAYLOCK_SCREENSAVER_FALLBACK_BG` knob: auto/none/path)
  - Per-hack flags via `~/.config/swaylock-screensaver/hacks.conf`
    (`<hack> <flags>`, `*` = all hacks; same file the swaylock-plugin
    contrib tools read), honored by both the lockscreen and the preview;
    `Alt+C` in the picker opens it in `$VISUAL`/`$EDITOR`
  - Express upgrades now migrate a restored stock `lock_cmd` in the user-owned
    `hypridle.conf` to the screensaver launcher, and land config files that are
    new in a release (e.g. the picker's rofi theme) without touching existing
    user files

## v2.3.25

## Fixed

- Pane selection bindings fail in lua configuration
- duplicate bindings for terminal
- Created wrapper script for `thunar`
  - Wasn't always starting in Debian lua config
- keybindings in scrolling layout
- `copy.sh` not copying all lua files
- `WallpaperEffects.sh` in lua config it changed theme not just wallpaper
- system keybinds in LUA config
- handling of SUPER-Q close active in LUA config
- keybinds handingling in LUA config
- wallpaper effects it would not restore original wallpaper
- wallpaper selector it was resetting waybar style sheet
- Layout code refactor:
  - Layouts are now per monitor/workspace
  - When you set a layout mode, i.e. scrolling
  - It will udpate the `~/.config/hypr/workspaces.conf` file
  - Therefore it will be persistent on next login
  - The current layout is shown in upper left corner
  - This fixes issue with setting `workspaces.conf` manually
    - When you selected a layout from menu the bindings didn't match
    - Also previously the layout was globally applied
      - Thanks to `@aki` for finding and reporting this issue
- WIP: Fixing icon spacing issues in Waybar
- Waybar would start then be restarted at login
  - Changed start order, `ThemeMode.sh` runs before waybar start
  - This restores users dark/light theme choice before waybar starts
- LUA: `QT_STYLE_OVERRIDE` in LUA was hard coded to `kvantum`
- LUA: Fixed `LuaAutoReload.sh` wasn't activating changes on save
- LUA: `lua_user_overides.lua` wasn't loading `system_keybinds.lua`
- `xdg-desktop-portal-hyprland` shows failed after CachyOS update
  - A regression bug in CachyOS is causing the issue
  - Screensharing doesn't work as a result
  - I created a script to create and override until they release the fix
    - In the `Hyprland-Dots` directory
      - Often located in `~/Arch-Hyprland=/Hyprland-Dots`
    - Run the script `config/hypr/scripts/Add-override-Hyprland-Portal.sh`
      - I will also be uploading the script to the Discord server
- NVIDIA Hybrid laptops have issues with cursors and GDM
  - Added more defensive code with fallbacks
- Dynamic wallpaper is now also per monitor
- Disabled LayerRule for swaync
  - Caused execessive blurring of background
- WindowRule for `qcalculate-gtk`
  - Had same rule as `gnome-calculator` needed own sizing
- Hybrid NVIDIA cursor handoff improvements
  - Enables Xcursor fallbacks and optional setcursor refresh on hybrid laptops

## Added:

- Sample `starship` config files
  - `copy.sh` now copies them to `.config/starship`
  - Will be adding menu later
- Migrated animation files from hyprlang to lua
- Launch scripts for `$term` and `$files`
  - Scripts check for presence or crashes
  - Has several fallbacks for each
    - kitty, ghostty, wezterm, alacritty, konsole, gnome-terminal
    - Thunar,dolphin,nautilus, $term -e yazi
- Added the additional LUA UserConfig files
  - `user_settings.lua`
  - `Window_rules.lua`
  - `layer_rules.lua`
  - `user_laptops.lua`
  - `user_env.lua`
  - `user_defaults.lua`
  - Etc..
- Migration to LUA script will migrate UserConfigs to LUA format
- Keybind `SUPER + ALT + F` to maximize window in `scrolling` layout
- Keybind `SUPER+R` to toggle column widths in `scrolling` layout
- Sample LUA workspace rules for setting layout per monitor/workspace
  ```lua
      hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", layout = "scrolling" })
      hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", layout = "dwindle" })
      hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", layout = "master" })
      hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", layout = "monocle" })
  ```
- Sample `hyprlang` (.conf) versions also
  ```ini
      workspace = 1, monitor:HDMI-A-1, layout:scrolling
      workspace = 1, monitor:HDMI-A-1, layout:dwindle
      workspace = 1, monitor:HDMI-A-1, layout:master
      workspace = 1, monitor:HDMI-A-1, layout:monocle
  ```
- Menu item in Quick settings, (SUPERSHIFT + E) to set Hyprlock background
- Dark / Light theme toggle is now persistant
  - At startup it checks and restores selection
  - `config/hypr/scripts/DarkLight.sh`
  - added persistent state file:` ${XDG_STATE_HOME:-$HOME/.local/state}/hypr/theme_mode`
  - keeps legacy sync with` ~/.cache/.theme_mode` for compatibility
  - defaults to Dark when no saved state exists
  - added flags:
  - `--apply-current`
  - `--mode Dark|Light`
  - `--no-notify`
  - `--preserve-wallpaper`
  - kept normal toggle behavior for manual use
  - `config/hypr/scripts/ApplyThemeMode.sh`
  - startup helper that runs:
  - `DarkLight.sh --apply-current --preserve-wallpaper --no-notify`
  - `config/hypr/configs/Startup_Apps.conf`
  - added startup call to re-apply saved mode:
  - `exec-once = sh -c 'sleep 4; sh $HOME/.config/hypr/scripts/ApplyThemeMode.sh'`
  - `config/hypr/lua/startup.lua`
  - added equivalent startup command for Lua startup flow

  ## Updated:
  - Moved `UserScripts/Wallpaper*.sh` and `ZshChangeTheme.sh` to `$scriptsdir`
    - They are system scripts not intended for user modification
  - Archived `UserScripts/Tak0-Autodispatch`
    - Not supported and no longer needed
  - Reset binding for fullscreen and maximize
    - `SUPER + F` is maximize
    - `SHIFT + SHIFT + F` is fullscreen
    - Now works in all layouts
  - Enabled 12 min timer on turning off monitor
    - For a very long that's been disabled by default
    - The suspend option is still disabled
  - Changed `$HOME` to `${XDG_CONFIG_HOME:$HOME}`
    - Compliant with standard especially with `UWSM`

---

## Fixed:

- `awww` default didn't work for wide screen monitors
  - Default is to `resize --crop`
  - Made wallpaper scripts monitor determinsitic
    - Just overriding default won't work for non ultrawide screens
    - Also add UserConfig override variabe to force default if needed
  - Thanks to **CateDesu** for finding issue & correct parameters
  - Found some corner cases and fixed them
- After LUA migration
  - Logout issues:
    - logout stopped working
    - Long delay 20s+ for logout when using SDDM
  - Duplicate keybinds
  - layout persistance code failed
- `cava` colors reloaded dynamically with wallpaper change
- Updated `initial-boot.sh` to set `prefer-dark `
  - This will set flatpak apps to dark
  - PortalHyprland now also has the ubuntu portal code
- Added script `scripts/DisableWaybarService.sh`
  - Some OS's / distros add a `waybar.service` to manage waybar
  - This breaks theming and waybar restarts
- `scripts/lib_copy.sh` wasn't preserving `UserConfigs` dir
- Bad import path in `.config/waybar/style/ML4W/glass.css` file
- Migration script didn't properly create the `system_settings.lua` file
- Logout is NixOS.
  - Added fallback if hyprshutdown not installed or fails
  - Fixed pathing issues where not all logout options used`Logout.sh`
- Removed sleep statments from startup to trim login time
- Network icon on waybar invisible
  - Changed the CSS files it's better but should revisit it
- NixOS waybar issues:
  - User waybar service enabled
    - `install.sh` checks for and disables on install
    - `Refresh.sh` now supports systemctl service as well
      - On NixOS waybar startup is wrapped `Refresh.sh` handles that also
- Parser for `UserConfigs` mistook border size 1 as as true/false value
- `UserConfigs/user_decorations.lua` was not being imported correctly
- My custom keybinds were included in defaults by mistake
  - Removed from both .lua and .conf files
- Theme by wallpaper and global theme
  - Neither were updating waybar nor border colors
  - Adjusted colors on style sheet `Wallust-Chrome-Fustion.css`
    - Current workspace showed as single color blob
- Migrate-hypr-to-lua to lua script
  - Wasn't properly handling variables list `$scriptDir`
- Sourcing of `UserConfig/user_keybinds.lua`
- Duplicate import of keybinds
  - was reading `lua/keybinds.lua` and `UserConfigs/configs`
  - Udpated `Kool_Quick_Settings.sh`
    - Only reads `configs` and `UserConfigs` dirs
- MonitorProfile for `eDP-1-disable.lua` incorrect
  - Changed to `disable = true`
- `copy.sh`
  - Didn't handle `hyprland.lua` properly
  - Re-copied `*.conf` files when LUA enabled
  - `monitors.lua` not copied to `UserConfigs` dir
  - `MonitorProfiles.sh` wasn't set up for LUA configuration
- `scrpts/migrate-hypr-to-lua.sh`
  - It didn't convert `monitors.conf` nor `workspaces.conf`
  - Impropved summary to show converted and what's left native
    - I.e. `hyprlock.conf` and `hypridle.conf` still use `.conf`
- `DropDownterminal`
  - Created `silent-mode` for startup
    - It now goes directly to specialworkspace
  - Adding lua support broke legacy hyprlang
  - Part Dos: Fixed the fix to work in lua workflow
  - Part Tres: `DropDownterminal.sh` exited on hide not persisted
- logout keybinding and logout from menu not working in LUA config
- logic issue in migration script
- Updated description for logout/exit keybinding
  - It only said `exit` if you search for `logout` nothing is returned
- Improved migration process to properly backup and move the .lua files
  - `/.config/hypr/lua` are the pristine source files
  - Migration script will convert the .conf files to .lua
    - Them move the system configs to `.config/hypr/configs`
    - Then move thhe user configs to `.config/hypr/UserConfigs`
    - Preserving user changes on subsquent updates
- `JavaManger.sh` field width cut off JDK version
- `Tak0-Autodispatch.sh`
  - Reworked code to support LUA config
- `Tak0-Per-Window-Switch.sh`
  - Had syntax error
  - Added support for both Hyprlang and LUA configs
- Incorrect XDGDATA dirs for flatpak
- `Gamemode.sh`
  - It supports both HYPRLANG and LUA configs
- `Float-all-windows.sh`
  - It works with HYPRLANG and LUA
- `MonitorProfiles.sh` script to work with LUA or HYPRLANG
  - Added additional profiles also
    - Virtual-1 1920x1080
    - Virtual-1 2560x1080
    - HDMI-A-1 High Refresh Rate
    - eDP-1 disable
- Legacy import of `UserKeybinds.conf`
- `Toggle-Active-Windown-Audio` script to work with LUA workflow
- `layerrules` made menus look terrible
- `OverviewToggle.sh` handling of quickshell vs. ags

## Updated:

- OpenSuse is not longer supported
- Updated lua defaults to disable hyprland wallpaper at start
- `ENVariables.conf` and `env.lua`
- migration script to make/keep proper Window Rule names
- LUA function to handle lid switch to enable/disable laptop display
- Thank you `@star` on `TheBlackDons` Discord Server
- keybind description for `hyprsunset` to include `hyprsunset`
  - Makes it easier to find in keybind search tool
- `ExternalBrightness.sh`
  - Taken from code modified by `@RAH-iĐ905`
  - Discovers montiors, and LUA compatible

## Added:

- `yazi` config to `copy.sh`
- Waybar widget for layouts
  - Shows current layout
    - `D` for `dwindle`
    - `S` for `scrolling`
    - `M` for `Monocole` (Capital M)
    - `m` for `master` (lowercase m in a circle)
  - Click on icon brings up menu to select layout
- Created helper lua modules for `UserConfigs` lua files
  - `user_keybinds_helper.lua`
  - `user_startup_helper.lua`
  - `user_window_rules.lua`
  - `user_layer_rules.lua`
  - `user_decorations.lua`
    - The removes the basic setup user lua files
    - The generated `user_keybinds.lua` now only has the bindings config
    - Removing all the setup code, functions, makes editing easier
    - Also any updates to the user keybind code is done outside of `UserConfigs`
      - `UserConfigs` dir is preserved on updates
- `SUPERCTRL + G` for ghostty theme selector
- Kitty theme selector to `Kool_Quick_Settings` to match entry for ghostty
- `.luarc.jsonc` and `hl.meta.lua` (Thank you @Tony,btw) for the latter
- This will get rid of `function not defined` errors in Editor LSP's that support LUA
- And provide fuction info as well with properly configured editors
- support for `$VISUAL` editor
- Setting the env variable to your GUI editor will override `$EDITOR`
- You can use `neovide`, `code/codium`. `geany`, `emacs` etc
- Providing a richer environment, and faster.
- Created a `keybind_helpers.lua` file
  - Moved all the helper functions which should need to be edited
  - This cleans up the `keybinds.lua` file to be more user friendly, easier editing
- Edited `keybinds.lua` to make it easier to understand and edit
  - Added a clear “User-editable bindings” header block.
  - Grouped bindings with section labels:
  - Application launchers and utility scripts
  - Window/session controls
  - Layout and tiling controls
  - Audio/media/hardware keys
  - Screenshot bindings
  - Window resize/move/swap/grouping
  - Workspace navigation/assignment
  - Mouse drag/resize bindings
- `Javamanger.sh`
  - Manage Java runtime instances
  - 1st pass, only tested for Arch
    - Added code for other distros, needs testing
- helper script `logout.sh` to call `hyprshutdown`
  - Added pkill `waybar`, `awww-daemon`, and `swww-daemon` before `hyprshutdown`
- menu option for `LayerRules` in Quick settings menu

## Removed:

- "-config-v3.conf" files for
  - `WindowRules.conf/lua`
  - `LayerRules.conf/lua`
    - They are no longer needed
- Hard-coded rofi terminal overrides in theme configs
  - `themes/KooL_dwm.rasi`
  - `dwm-config-horiz.rasi`
  - `dwm-config-vert.rasi`
- Thanks to [@TeaJhay](https://github.com/TeaJhay) for finding this

## Misc:

- Started planning changes to Wallust code to support v4.0
- `wallust v4.0.0` isn't backward compatible
- There seem to be more options but the color palletes are worse IMO
- Suggest current users ping wallust to v3.5.2

## Lua migration related:

- Improved move/resize and window swapping using native calls
  - Thanks to `TheAhumMaitra`
    - His LUA code is better than mine
    - I will probably be "borrowing" more ;)
    - https://github.com/TheAhumMaitra/Aurora
    - https://github.com/TheAhumMaitra
- Moved layer rules to own file `LayerRules.conf`
  - Added additional rules from `TheAhumMaitra`
  - Updated LUA config accordingly
- Began Migration process to LUA
  - Created `scripts/migrate-hypr-to-lua.sh`
  - Script converts `configs` and `UserConfigs` to LUA
  - Backs them up in local directories
  - Allows a revert option to restore hyprlang config files
- Making `Kool_Quick_Settings.sh` script LUA/HYPRLANG aware
- Broke out the `hypr/configs` and `hypr/UserConfig` LUA files
- Added project header to all .LUA files
- Migration script will add that to the converted .conf files as well
- Updated keybinds parser to support LUA
- Fixed resize by keybind, SUPERSHIFT= + Arrow keys
- Then modified that script to support mouse resize
  - SUPER + Left Mouse to move
  - SUPER + Right Mouse to resize

## v2.3.23

- Changed `whiptail` GUI to dark colors
  - Some terminals rendered incorrectly made menu unreadable
- Added more icons to `ModulesWorkpaces`
- Removed the following from hyprland settings:
  - `vfr` -- Been enabled by default
  - `psuedotile` -- In `dwindle` layout
  - As of Hyprland v0.55 they will generate confiuration errors
- `OverviewToggle.sh` wasn't checking properly for quickshell service
  - Found by `@TeaJhay`
  - Changed script to look for `qs` not `quickshell`
- Minimum Hyprland version is now v0.54.x
  - The addtion of scrolling and monocle require 0.54 or greater
  - Updated warning banner when you run `copy.sh`
- Added check for `kde-polkit`
  - With KDE installed users reported escalation fails
  - `kde-polkit` is crashing preventng privledge escalation
- Added `.config/hyprland/scripts/Polkit-Diag.sh`
  - This runs a series of Read Only commands to triage polkit issues
- Fixed syntax errors in a few waybar CSS files
  - What should have been `<TAB> color`
  - Was `\tcode` Caused by bad search and replace
  - It caused waybar to crash
- Updated `Keyhints.sh`
  - Was missing `scrolling` and `monocle` layouts
- Fixed display order for layout change binding
  - It showed `master` after `dwindle`
  - Correct order is `dwindle`, `scrolling`. `monocle`, `master`
- Added doc on how get `ventoy` GUI to run properly
  - Seems to be a known bug
  - `https://github.com/ventoy/Ventoy/issues/3570`
- Fixed issue with long pause starting lockscreen
  - In `~/.config/hypr/UserScripts/WeatherWrap.sh`
    - I put the weather cache check in the background
    - Shortened network timeouts for ping and curl
- Changed `ERROR` to `NOTE` when first installing dotfiles
  - The backup directory isn't there but reports as error
  - Thank you `@moukhtar22` for finding and reporting this
- Removed `grace` timeout from `hyprlock*.conf` files
  - It's now only supported on the command line
  - Also updated out the `#image` and `#label`
    - They require a space after the `#`
- Fixed: Setting wallpaper per monitor on restore both has same wallpaper
  - `WallpaperDaemon` only tracked one wallpaper
  - Added per monitor current wallpaper
- Added: Support for transistion effects with `awww`
- Added: `rofi-ssh-menu` `SUPER + S`
  - Reads hosts from `$HOME/.ssh/config`
  - You can also add in SSH keys to that file
  - Including for just local hosts and another for your repositories for example
- Removed: Some leftover `Jakoolit` references
- Added: WindowRule and icon for `shelly` unified app installer for arch
- Added: WindowRule for `hyprwcenter` Audio control app
- Updated: Waybar CSS files to use `font-size 14px`
  - Waybar, v15.x doesn't support `font-size 99%`
- Added: Script to disable Intel CPU Turbo feature
  - `$HOME/.config/hypr/scripts/disable.cpu.turbo.sh`
  - CPU turbo will often spin up the fan to max, then slowly drop back down
  - Very noisy, happens randomly. 11th/12th gen notorious for this issue
  - Should be added to User Startup as needed
- Fixed: Duplicate keybinds
- Fixed: `rofi beats` keybind not working

v2.3.22

- Fixed: Kitty font issue
  - Thank you `@JasonNero` for the fix
- Enabled `touch on tablet` in `hypr/configs/SystemSettings.conf`
- Updated `copy.sh` to support `ghostty`
- The ghostty config directory is now backed up
- Restore ghostty config added to restore options
- [S3cBar0n](https://github.com/S3cBar0n) updated `WallpaperSelect.sh`
  - It shows filename for the random image, and current wallpaper
  - Thanks for support Kooldots!
- `SWWW` project is archived moving to `AWWW`
  - It's feature, syntax compatible
  - Already has some fixes added
  - Created a startup script to check for `awww-daemon` or fallback to `swww-daemon`
  - Suggest everyone remove `swww` and replace with `awww`
    - This has been done in `NixOS-Hyprland` but you have to update to current build in main branch
- Fixed: Long delay updating colors after wallpaper change
- Added more app icons for `WaybarWorkspaces`
  - Emacs
  - Nautilus
  - Set new default icon to terminal with red X if no icon is available
- Fixed delay is `ScreenShot.sh` script
  - Removed existing `sleep` commands
  - Moved audio `Sound.sh` to background
  - This relates to `pipewire` [issue](https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/5155)
- Fixed delay in `Sounds.sh`
- Now uses `paplay` for sounds
- Rewrote core logic of `DropDownterminal.sh`
  - Doesn't use `specialworkspace` anymore
  - Updates to Hyprland seem to break old logic
  - The Dropdown would flash on hide
- Fixed `all float` toggle
  - Old command depreciated
  - Replaced with a script `Float-All-Windows.sh` in `Keybinds.conf` file
- Fixed Package name for `waybar-weather`
- Added `scrolling` layout
- Added `monocle` layout
- Experimenting with some additional layerrules
- Improving wallpaper based theming
  - More consistent results
  - Reducing the time to make change effective
- Fixed several waybar style files with inconsitent colors
- Updated `ChangeLayout` script for scrolling
  - Requires Hyprland v0.54+
- Added two keybinds for scrolling layout as a start
  - `SUPERSHIFT + comma` -- Swap columns
  - `SUPERSHIFT + period` -- Move to next column
  - `SUPERALT + H` -- Horizonal Scrolling
  - `SUPERALT + V` -- Vertical Scrolling
- Updated `togglesplit` to `layoutmsg,togglesplit`
  - The old format Has been depreciated, w/0.54 it's not supported
    - No errors just doesn't work
- Fixed many of the WALLUST based waybars color issues
  - Foreground/background colors were same light color
- Kitty now has a "No color/no theme" option
- Updated the Headers in the scripts to:
  - KoolDots
  - Added Project name and URL
  - Added License info GPLv3 to each file also
- Added new Rofi themes:
  - dwm Horizontal (old classic dmenu style)
  - dwm Vertical (dmenu with small dropdown list)
  - TokyoNight
- Changed `fastfetch` dotfiles name to `KoolDots`
- ENVvariables file had both QT5CT and QT6CT variables
  ````#Added style ENV for kvantum
   env = QT_QPA_PLATFORMTHEME,qt6ct
   env = QT_STYLE_OVERRIDE,kvantum```
  ````

## v2.3.21

- Added script from `@ivy` and `@sl1ng` to Toggle audio on active Wundow
  - `$HOME/.config/hypr/scripts/Toggle-Active-Window-Audio.sh`
  - Keybind is `SUPER + SHIFT + H` (hush)
  - Added check for `pactl` otherwise keybind fails silently
- Added check for ubunutu v26.04 in startup
  - For as of yet unknown reason waybar won't startup without this
  ```
  exec-once = /usr/libexec/xdg-desktop-portal-hyprland &
  exec-once = /usr/libexec/xdg-desktop-portal &
  exec-once = waybar
  ```
- Updated `waybar-weather`
  - Created default files in `.config/waybar-weather`
    - You can manually override settings or providers
    - The defaults should work for most users
  - Added question during install to set `metric` or `imperial` Temp units
  - Added Menu item is Quick Settings to toggle units
    - Note: After changing units click on the weather widget to update units
- Updated look of `fastfetch` compact config file
- Fixed no tooltips when `waybar cava` running
  - Thank you Max Gangel for the fix!
- Added check for `rsync` in `copy.sh`
- Fixed two more style sheets with hardcoded colors that broke with global theme
- Fixed Window Rules for `zapzap`
- Added French Translations
  - Moved docs to proper i18n locations
  - Thank you @Loris383v
- Fixed `waybar-cava` starting many new processes
  - When you switched waybarconfigs, old processes remained
  - This is especially bad with mulitple monitors
  - New code kills the `waybar-cava` processes on refresh
- Fixed setting SDDM/Wallpaper/Waybar defaults on update/installs
- Added WindowRule for proton-laucher games
- Added WindowRule for CachyOS Kernel Manager
- Added WindowRule for CachyOS Hello app
- Added WindowRule for CachyOS Package Installer app
- Added `Hyprshot` screenshot tool set to region capture
  - `ALT + S` Saves to clipboard and `~/Pictures/Screenshots/`
  - Not all keyboards have `PrtScr` button
  - `hyprshot.sh` is fast, simple, no system bell sound
- Fixed start CLI apps from rofi like `htop`, `btop` being started with `xterm`
  - This made the apps run in light mode with tiny fonts
  - Now they are started with `kitty`
- Added alternative `RainbowBorders-low-cpu.sh`
  - Based on code from `DemiGoD`
  - I added variables for finer control
  - Some tweaks to lower CPU further
  - Added `-h/--help`
  - Added `--run-once` to set RainbowBorders but no animation
- Added 'TOP-ddubs-simple-bar'
- Fixed CSS formatting in `ML4W-Glass.css`
- Added keybind for "Static Rainbow border"
  - Run `RainbowBorders-low-cpu --exec-once` to set the rainbow border w/o animation
  - Updated `Picture-in-Picture` rule
    - Works properly with `Brave` and other chromium browsers
      - Thanks to `Goodborn` for the fix

## v2.3.22 — fork additions

Tracks upstream's `v2.3.22` version marker; the entries below are fork-only
features layered on top of upstream and do not correspond to upstream releases.

- 2026-04-26
- Idle alert and post-lock watchdog
  - Pre-lock 30s warning fires `IdleAlert.sh warn` plus a notification
  - Post-lock `IdleWatchdog.sh` escalates squawks (gentle → nag → dumbass)
  - Battery-aware via `OnBattery.sh`: AC-attached idleness is silent and
    does not advance the escalation tier
  - Watchdog skips squawks while any monitor's `dpmsStatus` is `1`, so the
    flash routine no longer yanks dpms off mid-password-entry
  - Per-tier sound pools and watchdog cadence overridable in
    `~/.config/hypr/idle-alert.conf`
- Greenscreen waybar uber-narrow tier
  - New preset `[TOP] Greenscreen Uber-Narrow` for outputs below
    `WAYBAR_UBER_NARROW_THRESHOLD` (default 900px)
  - Auto-generator routes each output to wide / narrow / uber-narrow
  - Narrow preset: `fixed-center: true`, native `hyprland/workspaces#rw`,
    audio icon set, network with icons, battery moved into status drawer
  - Matching CSS adds backlight and network selectors for the narrow class
- Portrait laptop support
  - Ship `hyprlock-720p.conf` as a sibling to `-1080p` and `-2k`
  - `Wlogout.sh` detects portrait orientation and uses a 2x3 square-cell
    grid with margins computed for the portrait aspect
- Bind brightness keys in the laptop template
  - `xf86Mon/KbdBrightness` up/down → `Brightness.sh` / `BrightnessKbd.sh`
- Ship `base16-greenscreen` rofi theme in the repo
  - `config.rasi` previously referenced `/usr/share/rofi/themes/...` which
    nothing installed; theme is now under `config/rofi/themes/` with the
    `@theme` directive pointing at the user-config path
- Wlogout layout and styling refresh
  - Uppercase action labels, JetBrainsMono Nerd Font, smaller font/icons,
    tighter button radius and margins, hardened red for the danger button

## v2.3.20

- Bugfix release
- Fixed issue with express-update
  - It bypassed the code to remove duplicates in system vs. user
  - Now checks for dups in version <= 2.3.19
  - Improved the checking code for better matching system vs. User
  - Merged `tak0dan` update to `Tak0-Autodispatch.sh` script
  - Removed stale `nvim` config. It was never copied but not needed

## v2.3.19

- 2026-01-20
- Fixed CSS to format the `custom/nightlight` module
- Fixed padding on some CSS files

- 2026-01-19
- Removed "Set wallpaper SDDM prompt"
- When changing wallpaper there is no longer a prompt to set it on SDDM
- It's now a menu option under Quick Settings menu `SUPER SHIFT + E`
- Fixed `Glass` style sheets

- 2026-01-16
- Added `Rainbow Borders sub memu`
  - Code provided by [brunoorsolon](https://github.com/brunoorsolon)
  - There are now mulitple modes for the Rainbow Borders feature
  - `Disabled`, `Wallust Color`, `Rainbow`, `Gradient flow`
  - Thank you for the submission
- Disabled `RainbowBorders.sh` by default
- Use the quick setings menu `SUPERSHIFT + E` to enable, select mode

- 2026-01-15
- Created waybar configs for ML4W Glass style
- `TOP & Bottom Summit - glass`
- `Default Laptop - Glass`
- `Everforest - Glass`
- Fixed menu for express-update
- Fixed `Toggle Rainbow` checked for wrong file

- 2026-01-13
- Added `Toggle Rainbow borders` option to settings menu
- `SUPERSHIFT+E` search for `Rainbow`
- It will toggle the current state and run `Refresh.sh` to start or stop
  - Thanks to @Arkboi for suggesting it.
  - Later if there are more settings like this I will create a new menu

- 2026-01-11
  - Improved `ML4W Glass` theme
    - Now has proper 3d gradient look
    - Theme based nightlight color
  - `copy.sh` is now more modular
    - Helper scripts in `scripts` dir per function
    - Making `copy.sh` smaller (1200 lines to 800 so far)
    - Easier to maintain going forward

- 2026-01-09
  - Fixed: Keybind parser latency
    - Changed the parsing login to python instead of bash
    - Also fixed duplicates when you unmap, then remap keybinds
      - Ex. Change keybind for `file manger`
        - Both the old and new keybind were show in keybind menu
  - Added: `--express-update` to `copy.sh`
    - `./copy.sh --express-update`
    - This will bypass some of the questions
      - Updating SDDM wallpaper
      - Downloading wallpaper from repo
        - Mostly like that was done at install time or previous upgrade
      - Restoring User configs :
        - `Weather.sh` and `Weather.sh`
        - `Rofibeats.sh`
        - etc.
      - Automatically trims the backed up directories leaving just latest backup
      - This dramatically reduces the time/effort to update dotfiles
        - Most users don't restore these custom files on upgrades

- 2026-01-08
- Fixed: MPRIS artwork in Sway notification center only 10 pixels
  - Adjusted to 96 pixels
  - Thank you @godlyfas for fixing this
- Fixing scripts
  - `TouchPad.sh` never expands `$TOUCHPAD_ENABLED` (and doesn’t source the file that defines it)
  - `Volume.sh` has multiple microphone-control bugs (bad `pamixer` arguments, typoed function name, invalid notification payloads) that break mic toggling and volume feedback.
  - `DarkLight.sh` wipes the Qt theme paths each run because the `qt5ct/qt6ct` palette variables are commented out.
  - `KooLsDotsUpdate.sh` contains a malformed `notify-send` string that crashes the script when no local version is detected.
  - `Distro_update.sh` runs `sudo apt upgrade` outside the kitty window, so the Debian/Ubuntu flow never finishes inside the terminal.
  - `Hypridle.sh` now launches `hypridle` in the background (`& disown`) when enabling the daemon, preventing the toggle command from hanging Waybar.
  - `RofiSearch.sh` verifies that `jq` is available, captures the user’s query explicitly, URL-encodes it via `jq` `@uri`,
    - opens the configured search engine with the encoded query instead of dropping the term.
  - `Sounds.sh` now tries `pw-play`, then `paplay`, then `aplay`, emitting a clear error if none are installed, so the script no longer calls the non-existent pa-play.
  - `Tak0-Per-Window-Switch.sh` now records the listener PID in `~/.cache/kb_layout_per_window.listener.pid` and reuses it if still running, preventing multiple background listeners, and reports missing Hyprland sockets without exiting the main script.
  - `WaybarScripts.sh` adds a `launch_files()` helper that checks `$files` before execution; if unset, it shows a notification instead of running an empty command.
  - `sddm_wallpaper.sh` validates `~/.config/rofi/wallust/colors-rofi.rasi` before use, extracts colors via a helper, and aborts with a notification if any required colors are missing.
  - `WallustSwww.sh` now reads the focused monitor’s cache file (or parses swww query per-monitor) to pick the correct wallpaper path
    - Eliminating the previous “last line wins” bug on multi-monitor setups.
    - Wallpaper and global theme changes are now dramatically faster
  - `PortalHyprland.sh` suppresses harmless killall errors and launches only the first available portal binary in each category (hyprland + general)
    - Avoiding duplicate processes when both `/usr/lib` and `/usr/libexec` variants exist.
  - `KillActiveProcess.sh` checks that Hyprland returned a numeric PID before calling kill
    - Notifies the user when no active window is available instead of throwing kill usage errors.

- 2026-01-06
  - Added Global Theme Changer.
    - There are many themes to choose from
    - `SUPER + T`
  - Added "Glass Style" taken from `ML4W` dotfiles
    - Thank you [TheAhumMaitra](https://github.com/TheAhumMaitra)
  - Fixed more WindowRules
  - Fixed rofi themes to work with Theme changer
  - Added `ghostty` terminal config file integrated with Themes
    - `ghostty` is not installed by default
    - The `COPR` is already there for Fedora
      - `sudo dnf install ghostty`
  - The `COPR` repo for `wezterm` is also available
    - `sudo dnf install wezterm`
    - A config file is already available when you install it
    - Most other distros have these terminals in their repo

- 2026-01-04
- Fullscreen or maximized would exit using `ALT-TAB` (cycle next/bring-to-front)
  - User `GoodBorn` found this fix

  ```
  misc {
   on_focus_under_fullscreen = 1
   # 0 - Default, no change
   # 1 - New focused window takes over fullscreen (Windows-like Alt-Tab)
   # 2 - New focused window stays behind the fullscreen one
   }
  ```

  > Note: The above change only works on Hyprland v0.53+.
  > Users with lower will have to comment that line out.
  > `~/.config/hypr/UserSettings/SystemSettings.conf`

- Added: modal rule so popup diaglog, like `Save as` or `Open File` center and float by default
  - `windowrule = float on, center on, match:modal:1`

- 2026-01-01
- Added more blur and enabled xray
  - Thank you [TheAhumMaitra](https://github.com/TheAhumMaitra)

- 2025-12-31
  - Fixed rule for `Gnome Calculator`
    - Thanks Warlord for finding/fixing that
  - Fixed rule for `yad`
    - Size was being overridden by `settings` tag
  - `~/Pictures` now follows `XDG dir` vs. hard coded
    - Thanks for Jaël Champagne Gareau for the code
  - Fixed `opache toggle`
  - `Weather.py` and `Weather.sh` updated and improved
    - Thank you Lumethra
  - Added network check to `WeatherWrap` script
    - Thank you Maximilian Zhu
  - Added sample workspace rules to start apps on specific workspaces
    - They are commented out but serve as references

- 2025-12-29
  - Fixed pathing in Wallust script
    - Thank you [Lumethra](https://github.com/Lumethra)

— 2025-12-22

- Added:
  - Optional keybinding to increment/decrement audio in 1% steps vs. 5%
    - Thanks [rgarofono](https://github.com/rgarofano) for the code
- Fixed:
  - Switch Layout was looking in wrong location
  - SUPER - J/K not working in both `master` and `dwindle` layouts
    - You also get notification message on layout change
    - Thanks [@suresh466](https://github.com/suresh466) for fixing it

## v2.3.18 — 2025-12-10

## FIXES:

- Updated: Made the WindowRules file for 0.53+ the default
  - There are more distros now running 0.53.1 vs. earlier versions
  - The older file is still there for those users not yet up to date
- Fixed: Opacity for `vscode` configured multiple times
- Fixed: Quickshell `overview` not working, error "Quickshell or AGS not installed"
  - If `shell.qml` exists in `~/.config/quickshell` that blocks overview
  - That file isn't configured for overview
  - Without that file, it will look in the `overview` directory and load the QML code
- Fixed: Waybar Modules, locale not included in clock format
  - Always showed US-EN
  - Thanks to albersonmiranda for finding and fixing it
- Fixed: Not all waybars had `custom/nightlight`
- Fixed: `Weather.py` cache wasn't updating when UNITS changed from C to F
- Fixed: Wallpapers with periods in names truncated
  - https://github.com/LinuxBeginnings/Hyprland-Dots/pull/873
  - Thanks to @godlyfast for the fix.
- Fixed: Overview Toggle keyind SUPER + A now properly detects QuickShell
  - If QS `overview` fails, or is not installed, AGS `overview` will be started instead
- Fixed: `Super J/K` cycle next/prev weren't working in both master / dwindle
- Fixed: `Weather.py` one-off run
- Removed: `Hyprsunset` from status group.
  - Credit: Alberson Miranda
- Added: more application icons for waybars
- `Weather.py` basically rewritten to improve look and functionality
  - Credit: Prabin Panta
  - The Jak team also heavily contributed to the rewrite
- Fixed: Waybar
  - Changing the waybar config `SUPERALT + B` would sometimes need to be done twice
  - Cause: options were incorrect annotated with "👉 ${name}"
- Fixed: `GameMode.sh` to function consistently
- Updated: `WalllustSwww.sh` wallpaper path
- Corrected: Typo in Show Open Apps
- GameMode.sh / Refresh.sh
  - Enabling / Disabling repeatedly would result in multiple waybars
  - Added additional `sleep` commands in `GameMode.sh` and `Refresh.sh`
  - Resolves [Issue 870](https://github.com/LinuxBeginnings/Hyprland-Dots/issues/870)

## CHANGES:

- ChangeLayout.sh continues to rebind dynamically when layouts are toggled.
  - Credits: [Suresh Thagunna](https://github.com/suresh466)
  - For identifying the mismatch and proposing an auto-alignment approach.

- Startup config order:
  - load System Defaults Startup_Apps and WindowRules first
  - Then user overlays, restoring baseline autostarts while keeping user additions.
- Lock screen:
  - Clock now horizontal and smaller
  - Adjust spacing margines of the various fields
  - Small changes to color variables Trying to balance colors
  - Fixed both 1080 and 2K+ configurations
- `UserConfigs/Startup_App.conf` is now sourced in `hyprland.conf`
  - It was being sourced twice
- Some scripts weren't executable
  - `scripts/Battery.sh`
  - `scripts/ComposeHyprConfigs.sh`
  - `scripts/OverviewToggle.sh`
  - `scripts/sddm_wallpaper.sh`
- Updated: SWWW to v0.11.2
  - Fixes numerous issues
  - Portrait monitors especially
  - SWWW isn't being maintained In future will switch to AWWWW
- Added: A message before installing wallpapers that some are AI generated or enhanced
- Changed: `/usr/bin/bash` to `/usr/bin/evn bash` for better portability
- Adjusted: Small change to `DropDownterminal.sh`
  - Increased top margin % to center it more
  - Widened it.
  - These options are settable in the script.

## FEATURES:

- Hyprsunset retains last state on/off
  - Credit: Alberson Miranda
- Fastfetch now displays the version of the Jak Dotfiles
- `ChangeLayout.sh`
  - Dynamically binds SUPER J/K based on current layout
  - Previously only worked in Master Layout
  - Credit: Suresh Thagunna
  - Along with that `KeybindsLayoutInit` script reads current default layout
  - Then it adjusts the SUPER J/K keybindings appropriately
- RofiBeats dynamic music system added
- Binds now include descriptions.
  - Switched from `bind` to `bindd`
  - Improves usability of keybind search
- Add new laptop gesture for zoom system.

Thanks to everyone that contributed, or reported issues.

Contributors:

Alberson Miranda
TheAhumMaitra
Prabin Panta
Suresh Thagunna
@goldlyfast

## October 2025

### ⌨️ Keybinds

- Convert Hyprland keybinds to description form (`bindd`, `bindld`, `binded`,
  `bindmd`, `bindlnd`) in `config/hypr/...`.
- Add concise descriptions for each keybind; keep the name "powermenu".
- Update `config/hypr/scripts/KeyBinds.sh` to parse and display descriptions as:
  MODS+KEY — DESCRIPTION — DISPATCHER [PARAMS].

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

If you have any questions, feel free to contact via
[GitHub Discussions](https://github.com/LinuxBeginnings/Hyprland-Dots/discussions) or
[Through Discord Server](https://discord.gg/kool-tech-world)
