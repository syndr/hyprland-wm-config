# Changelog — KoolDots

## Unreleased

## Fixed

- **Grey screen after upgrading past #19 (`feat(startup)`).** That change
  stopped sourcing the vendor `configs/Startup_Apps.conf` in favour of systemd
  user units that were assumed to exist in `~/.config/systemd/user/` -- they
  had only ever been hand-written on one host. Every other host came up with
  Hyprland running and nothing painting: no wallpaper daemon, no waybar, no
  hypridle. The units now ship in the repo and the installer wires them. See
  [`docs/adr/run-session-daemons-as-systemd-user-units.md`](docs/adr/run-session-daemons-as-systemd-user-units.md).

## Changed

- **Session daemons are systemd user units shipped by the repo.**
  `config/systemd/user/` carries `hyprland-session.target` and units for the
  wallpaper daemon (awww preferred, swww fallback), nm-applet, cliphist,
  quickshell overview, copyq, ags and IdlePowerWatch, plus `LimitNOFILE`
  drop-ins for the distro waybar, hypridle and plasma-polkit-agent units.
  `install_session_units` (`scripts/lib_units.sh`) copies them, unmasks
  waybar/hypridle where a host had masked them, enables each unit whose
  program exists, wants the distro waybar/hypridle/blueman-applet and exactly
  one polkit agent, and starts the target in a running session.
  - Session bring-up (`uwsm finalize` / `systemctl --user start
    hyprland-session.target`, environment export, `hyprpm reload`, keybind and
    dropdown-terminal init) moved to the vendor-owned
    `configs/Startup_Session.conf`, which is deployed on every upgrade.
    `UserConfigs/Startup_Apps.conf` is for the user's own apps only;
    `migrate_startup_overlay` strips lines the new file or a unit now owns
    (timestamped backup).
  - `Hypridle.sh`, `Refresh.sh`, `WaybarLayout.sh` and `WallpaperSelect.sh`
    drive the unit when one is loaded instead of pkill/relaunching a daemon
    outside systemd.
  - The post-upgrade audit warns when `Startup_Session.conf` is not sourced,
    `hyprland-session.target` is not enabled, waybar/hypridle are masked, or
    waybar/the wallpaper daemon are not wanted by the target.

- **Claude Code "waiting for your input" notifications are toast-only.**
  kitty forwards them with summary `Claude Code` and no transient hint, so
  swaync kept every one in the control center. A `notification-visibility`
  rule in `swaync/config.json` marks them `transient` and re-files them as
  critical: the popup stays until dismissed (swaync has no per-rule timeout),
  nothing is left in the center. Express upgrades preserve an existing swaync
  config, so add the rule by hand on already-deployed hosts (or reload after
  copying it).

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
- `copy.sh` offers to reload the running session when it finishes. It writes
  files but never touched the live compositor, so until the next login the
  deploy and the session disagreed -- new keybinds absent, window rules and
  waybar modules stale, and a regenerated `hypridle.conf` ignored by the
  hypridle already running. That reads as a failed upgrade when the files are
  in fact correct. `offer_session_reload` runs `hyprctl reload`, reports any
  config errors, reloads hypridle, starts `IdlePowerWatch.sh` if it is not up,
  and calls the existing `Refresh.sh` for waybar/swaync/rofi. Express does it
  automatically; interactive runs prompt; it skips cleanly with no live
  Hyprland session or no terminal. A logout is still worth doing for what a
  reload cannot pick up (env vars, `exec-once`).
- The idle stack logs what it does to `~/.local/state/kool-dots/idle.log`:
  screensaver pause/resume, screen on/off, AC/battery flips, deferred reloads
  and config renders. These scripts are fired by hypridle and udev with no
  terminal attached and their output went to `/dev/null`, so there was no way
  to tell after the fact what had happened. hypridle's own output (listener
  registration, spawn failures) now lands in
  `~/.local/state/kool-dots/hypridle.log`, truncated on each hypridle start.
  `KOOL_IDLE_LOG=0` disables the former; the log is trimmed to 500 lines.

## Fixed
- **Desktop zoom (SUPER ALT + scroll) stepped about ×2.5 per notch and
  scrolled the window underneath.** The bind was defined twice
  (`configs/Keybinds.conf` at ×2.0, `UserConfigs/UserKeybinds.conf` at ×1.25),
  both firing on every notch and racing on the same `hyprctl getoption` /
  `keyword` pair. Hyprland's `binds:scroll_event_delay` (default 300 ms) then
  passed every wheel event inside that window through to the focused app, so a
  hi-res wheel or the trackball-scroll daemon scrolled the page while zooming;
  horizontal wheel drift was unbound and leaked the same way; and the awk clamp
  ran before the divide, so zooming out went below 1.0. The vendor
  `Keybinds.conf` now owns the binds: `scripts/Zoom.sh` steps ×1.05 per wheel
  event (`KOOL_ZOOM_STEP`) and clamps to exactly 1.0, `scroll_event_delay` is
  0, horizontal wheel is bound to the no-op `event` dispatcher while the chord
  is held, and SUPER ALT 0 resets. SUPER + scroll workspace switching keeps its
  300 ms cadence through the new `scripts/WheelThrottle.sh`, which consumes
  the event instead of passing it on. Because upgrades restore `UserConfigs/`
  from backup, `copy.sh` now migrates the legacy inline zoom binds out of a
  restored `UserKeybinds.conf` (`migrate_legacy_zoom_binds`, backup
  `*.backup-zoomfix-*`), and the post-upgrade audit warns when the same key
  chord is bound in both `Keybinds.conf` and `UserKeybinds.conf`, not only on
  identical lines.
- One wake produced three `dpms on` and three `resumed` log entries.
  hypridle fires `on-resume` for every rule that had elapsed, and each
  blanking rule needs its own (a rule that never elapsed cannot un-blank), so
  three arrive at once by design. They raced: all three read the pause stamp
  before any cleared it. `ScreenPower.sh` and `ScreensaverPause.sh` now
  serialise on their own `flock` descriptors (fd 7 and fd 8, distinct from the
  fd 9 instance lock so the nesting cannot deadlock) and act only on a real
  transition, so redundant callers neither re-dispatch to Hyprland nor log.
  A resume still always reaches the hack, so it cannot be left stopped behind
  a lit screen.
- The screensaver window was cut short after an idle lock. hypridle counts
  every timeout from the last input event, so the "manual lock" screensaver
  listener at `SCREENSAVER` seconds also fired after an idle lock -- only
  `SCREENSAVER - LOCK` seconds into it. On the AC defaults a 20-minute
  animation lasted 5. Caught in the new log: an idle lock at 00:16:56 blanked
  at 00:21:56, exactly 1200s after the last activity rather than 1200s after
  the lock. The manual-lock listeners (screensaver and the hyprlock blank
  delay) are now gated on `LockerAge.sh`, so they only fire when the locker is
  genuinely that old, leaving the `lock + window` listener to handle idle
  locks. Present in the hand-written config this generator replaced.
- `ScreensaverPause.sh` logged a line per hypridle listener rather than per
  actual transition -- several fire in the same second, so one wake produced
  four "resumed" entries. It now reports only real state changes.
- `IdlePowerWatch.sh` could be permanently blocked from restarting. Its
  single-instance `flock` lives on fd 9, which children inherit: both the
  `udevadm monitor` co-process and the hypridle started by a profile reload
  outlived the watcher and kept the lock held, after which every start exited
  "already running" for the rest of the session. Observed live -- an orphaned
  `udevadm` had held it since login. The uevent stream is now opened on its
  own descriptor with fd 9 closed in the child and killed on exit, and
  long-lived spawns close the descriptor explicitly.
- `IdlePowerWatch.sh` spun at ~8% CPU after a `SIGTERM`. A trap that only
  cleans up does not stop the script, so the loop carried on reading an
  exhausted descriptor. The signal traps now exit, and an EOF on the uevent
  stream (as opposed to a read timeout) exits rather than looping.

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

## v2.3.28

## Fixed:

- A `monitors.lua` refresh-rate edit survives `hyprctl reload`
  - `MonitorWatcher.sh` re-applied the recorded layout on `configreloaded`
  - The record still held the previous mode, so the edit was undone in ~2s
  - It now asks `DisplayProfile.sh config-newer` and stands down when edited
  - The check compares mtimes against the recorded layout
  - `UserConfigs/monitors.lua`, `lua/monitors.lua`, `user_laptops.lua` count
- `HDMI-A-1-HighRefreshRate` no longer drops to 1024x768
  - `mode = "highrr"` is the highest refresh rate at any resolution
  - A 1920x1080@75 panel also advertises 1024x768@75.03, which won
  - The profile now asks for `1920x1080@75` explicitly
  - `Monitor_Profiles/` is restored from backup, so an install needs a patch
  - `patches/85-monitor-profile-refresh-rate.sh` replaces it when unedited
- Disabled monitor broke `nwg-displays` parser
- Moved waybar `network#speed` network mgr `nmtui` to Modules
  - It was per bar and not consistent
  - Thanks Leonardo Araujo @leolca
- Legacy `hyprctl dispatch` calls no longer silently do nothing
  - Since Hyprland 0.55, `hyprctl dispatch` is a shorthand for `hl.dispatch(...)`
  - A dispatcher name plus arguments is parsed as Lua, so `workspace e+1` fails
  - `waybar/ModulesWorkspaces` scroll handlers use `hl.dsp.focus({ workspace = ... })`
  - All 7 modules carried the same dead pair, 14 handlers in total
  - `raw_dispatch_cmd` emitted `hyprctl dispatch <name>`, which could never run
  - It now warns once per name at config load and returns `hl.dsp.no_op()`
  - The two copies are `system_keybinds.lua` and `user_keybinds_helper.lua`
  - `Logout.sh` drops the `exit 1` / `exit 0` / `exit x` variants
  - `exit` takes no argument in either mode, so they could never succeed
  - `Logout.sh` spawns hyprshutdown through `hl.dsp.exec_cmd(...)`
- Editing `UserConfigs/*.lua` applies on save, with no `hyprctl reload`
  - Hyprland's built-in autoreload watches only the entrypoint `hyprland.lua`
  - Other files the config loads arrive through `dofile`, which it never sees
  - A saved `UserConfigs` file stayed inert until a manual reload
  - `scripts/LuaConfigWatch.sh` watches `lua`, `configs` and `UserConfigs` for `*.lua`
  - On a save it debounces, then touches `hyprland.lua`, the watched path
  - Saves of non-`.lua` files in those directories are ignored
  - One instance per user; it exits cleanly on `SIGTERM` and removes its pidfile
  - Falls back to `hyprctl reload` when `misc:disable_autoreload` is on
  - Falls back to 1s polling where `inotify-tools` is not installed
  - A syntax error in a saved file raises a notification
- Waybar no longer fails to start on boot or after screen lock
  - `startup.lua` chained `WallpaperDaemon.sh` and `WaybarStartup.sh` with `&&`
  - A wallpaper delay or failure blocked Waybar from ever launching
  - `WaybarStartup.sh` used `flock -n`, dropping concurrent restarts
  - `WallustSwww.sh` sent `SIGUSR2` while Waybar was still initializing
  - `startup.lua` now launches them as separate startup commands
  - `WaybarStartup.sh` uses bounded wait on its lock, preserving restarts
  - `WaybarStartup.sh` discovers and exports `HYPRLAND_INSTANCE_SIGNATURE`
  - `WallustSwww.sh` skips signalling while Waybar holds the startup lock
- Duplicate waybars when opening laptop lid
- Opening the lid turns the laptop panel back on
  - `user_laptops.lua` replayed the stored `monitors.lua` rule as it was
  - A rule that omits `disabled` does not switch an output back on
  - So the panel stayed dark and its workspaces stayed on the external screen
  - The branch now always sets `disabled = false`, keeping the stored mode
  - `patches/83-user-laptops-lid-open.sh` fixes existing installs
- The only screen stays on, at the origin, when nothing else is connected
  - The no-externals branch replayed the stored `monitors.lua` rule as it was
  - A rule that omits `disabled` does not switch an output back on
  - A rule from a monitor set that had more kept its old position
  - So the only screen could come back dark, or off the origin
  - The branch now forces `disabled = false` and `position = "0x0"`
  - A stored `transform` is carried over too, which the branch dropped
  - `patches/84-user-laptops-single-monitor.sh` fixes existing installs
- The animation chosen from the menu no longer resets to the defaults
  - `copy.sh` copies the repo's `UserConfigs` before the migration runs
  - The shipped comment-only `user_animations.lua` was already in place
  - The migration kept any existing `user_animations.lua`, placeholder and all
  - On a hyprlang install the choice lives in `UserAnimations.conf`
  - `migrate-hypr-to-lua.sh` converts it to `hl.curve`/`hl.animation` Lua
  - A preset the Animations menu wrote is still left untouched
- Rofi and wlogout selections no longer reset on an upgrade
  - `copy_phase2` replaces `hypr/` and `wlogout/` with the repo copies
  - The rofi `@theme` line and `wlogout/.current_theme` were never restored
  - `restore_hypr_assets` now carries the active rofi theme into `config.rasi`
  - `restore_wlogout_selection` re-applies the saved wlogout preset
  - `RofiWlogoutTheme.sh` reads `.current_theme` back into `CURRENT_PRESET`
- The restore helpers no longer look in the wrong backup directory
  - They declared `local BACKUP_DIR`, hiding the cached suffix
  - `get_backup_dirname` then generated a fresh timestamp per call
  - A run crossing a minute boundary restored from a path that never existed
- Monitors no longer default to the largest mode a panel advertises
  - `ds_generate` took the biggest available mode, not the one in use
  - A VM's `Virtual-1` was pinned to `5120x2440@50` on every boot
  - It now keeps the mode already on screen, the panel's own `preferred` choice
- A boot no longer overwrites `UserConfigs/monitors.lua`
  - `DisplayProfile.sh auto` rewrote the file on every login, not on an apply
  - Hand edits were replaced, and the shipped `Virtual-1` rule was overridden
  - Only an explicit apply or an nwg-displays drag writes it now
- The shipped wildcard monitor default is `preferred`, not `highres`
  - `lua/monitors.lua` chained `preferred`/`highrr`/`highres` for `output = ""`
  - The last matching rule wins, so every output was asked for `highres`
  - `Monitor_Profiles/default.lua` had the same chain
- Layout-aware focus binds no longer fork a script per keypress
  - `SUPER + j`/`k` and `SUPER + arrow` ran `LayoutKeybindDispatch.sh`
  - It spawned bash, 4-8 `hyprctl` and `jq` processes on every press
  - Ported to `lua/window_actions.lua` as `layout_cycle`/`layout_focus`
  - Tries the layout message first, falls back only if focus did not move
  - Scrolling uses `hl.dsp.layout("focus l/r")`, monocle `cyclenext`/`cycleprev`
  - Everything else uses `hl.dsp.focus` and `hl.dsp.window.cycle_next`
- `ALT + Tab` and user `cyclenext` binds now cycle in-process
  - `LuaCycleWindow.sh` spawned bash, 2 `hyprctl` and a `jq` program per press
  - Ported to `lua/window_actions.lua` as `cycle_window`, address-sorted order
  - `dispatch("cyclenext")` in user configs fell through to a dead legacy name
  - `lua/user_keybinds_helper.lua` now maps it to the in-process action
- Waybar no longer polls `hyprctl` on a timer
  - `custom/hypr_layout` ran `HyprLayoutModule.sh` every 2s
  - That reached `ChangeLayout.sh` and then `hyprctl -j activeworkspace | jq`
  - `custom/keyboard` ran `KeyboardLayout.sh status` every 1s
  - It makes four `hyprctl devices -j | jq` calls per run
  - About 4.5 `hyprctl` + 4.5 `jq` forks per second, for the whole session
  - Both now subscribe to the Hyprland event socket in `HyprEventWatch.sh`
  - They re-render only when the state they show actually changes
  - `HyprLayoutModule.sh` reads the layout over the socket, not `hyprctl`
- Gesture zoom no longer freezes the compositor
  - The 3-finger swipe ran `io.popen("hyprctl ...")` on the compositor thread
  - `io.popen` waits for the child, so the session stalled for the round trip
  - It also wrote through `hyprctl keyword`, the legacy hyprlang form
  - Now one in-process `hl.get_config` / `hl.config` pair, clamped to 1.0-16.0
- Laptop monitor layout no longer shells out from the compositor
  - `user_laptops.lua` used `io.popen` for the lid-state fallback
  - `connected_drm_connectors()` ran one `io.popen("ls ...")` per DRM card
  - Lid state now reads fixed sysfs paths, connectors use plain file reads
- Layout label refresh now goes through the Hyprland socket
  - Waybar only re-execs a custom module while the script is not running
  - Both status modules loop, so `signal: 8` never fired
  - The label went stale until the next workspace switch
  - `ChangeLayout.sh` and the layout menu now emit `custom>>kool:layout`
  - `hypr_emit_event` in `HyprIPC.sh` sends it; the listener re-renders on it
- `HyprLayoutModule.sh` had lost its `change_layout` path
  - `set_layout` called an empty variable, so the layout menu set nothing
- Night light icon updates on change instead of a 3s poll
  - `custom/nightlight` re-ran bash + pgrep every 3s for a manual label
  - `Hyprsunset.sh` pushes RTMIN+9 on change and reads its state without `cat`
  - The module keeps a 60s interval for hyprsunset exiting outside the script
- Existing installs never received the layout-refresh throttle
  - `copy.sh` protects `UserConfigs`, so shipped copies kept the old code
  - `patches/70-user-laptops-refresh-throttle.sh` inserts it in place
- Two Waybar bars no longer kill each other's status listeners
  - The guard was keyed by module name only, so a second bar replaced it
  - Waybar then reported `stopped unexpectedly` and re-ran it every 10s
  - It is now keyed by the parent bar; a listener exits when its bar does
- A shut laptop lid no longer switches off its only screen
  - `user_laptops.lua` disabled the internal panel whenever the lid closed
  - With no external monitor that left the session with no output at all
  - The panel now stays on unless another monitor can show the session
  - `patches/80-display-layouts.sh` applies the same fix to existing installs
- A killed `MonitorWatcher.sh` no longer strands its own lock
  - The event stream runs in a process-substitution subshell that outlives it
  - `9>&-` on the call inside `<(...)` left bash's saved copy of fd 9 open
  - So the subshell held the flock, and no watcher could start until socat ended
  - The subshell now closes fd 9 with `exec 9>&-` before it starts the stream
- Existing installs kept the old `Monitor_Profiles/README`
  - On upgrade it is restored from the backup, so the shipped copy never lands
  - `patches/81-monitor-profiles-readme.sh` appends the current notes instead
  - It appends rather than replaces, so a user's own notes there survive
- Waybar no longer goes missing after a restart
  - A bar that was just signalled can linger while it dumps core
  - `pgrep` kept matching it, so the relaunch thought a bar was already up
  - It skipped its own launch, so the session had no bar until the next try
  - `is_waybar_running` now ignores `Z` (exited) and `D` (dumping core)
  - A stop waits for the bar to leave, and a restart forces the launch
  - `LidSwitch.sh` asks the same question before signalling a bar
  - Issue: [#158](https://github.com/LinuxBeginnings/Hyprland-Dots/issues/158)
    - Thanks again Angel Spano @jasueh for the info to find issue
- The keybind search menu was missing binds that were active
  - `KeyBinds.sh` regexed the keybind files with `keybinds_parser.py`
  - It printed the source text, so it could not see what the helpers derive
  - 12 were absent: 10 `SUPER SHIFT + number` variants, 2 lid switches
  - Media keys read as `xf86audiomute` rather than `XF86AudioMute`
  - The menu now lists the binds the compositor actually has
  - So it cannot under-report, and it follows an override or an unbind
- Waybar's `network#speed` module no longer ignores right-click
  - The `network` block set `on-click-right`, `network#speed` set none
  - Waybar looks up `config["network#speed"]`, not the parent module
  - The instance now runs `WaybarScripts.sh --nmtui`, as `network` does
  - Issue: [#161](https://github.com/LinuxBeginnings/Hyprland-Dots/issues/161)

## Added:

- `END4-smooth.lua` animation preset
  - From current END4 dotfiles
  - https://github.com/end-4/dots-hyprland
  - Drops three `expressive*Spatial` curves nothing referenced
  - Adds `global` and `fade`, which upstream leaves unset
  - Affects `fadeSwitch`, `fadeShadow`, `fadeGlow`, `fadeDim`, `fadePopups*`
  - Those now take the preset's timing, not Hyprland's stock values
  - Retimed: `windowsIn`/`fadeIn` 4.9, `windowsOut`/`fadeOut` 2.9
  - `workspaces` 30, so the slide is visibly slower than upstream's 7
- `PR43` animation preset
  - https://github.com/43PR/dotfiles
- Indicator to mark current animation
- Indicator to mark the current Rainbow Borders mode
  - `Kool_Quick_Settings.sh` marks the mode in effect and pre-selects it
  - The marker is stripped before the choice is used as a mode
- Indicator to mark the current selection in the other pickers
  - `Kitty_themes.sh`, `Ghostty_themes.sh`, `RofiThemeSelector.sh`
  - `ChangeStarshipPrompt.sh` and `ZshChangeTheme.sh` had none at all
  - `ThemeChanger.sh` marked the theme but never pre-selected the row
  - `select-hyprview-layout.sh`, `MonitorProfiles.sh`, wlogout blur level
  - The marker is stripped again before a choice is read as a name or path
- `config/hypr/scripts/tests/test-migrate-animations.sh`
  - Covers carrying the animation from `UserAnimations.conf` into Lua
  - 11 checks, from a sandbox `XDG_CONFIG_HOME` with no session
- `config/hypr/scripts/tests/test-installer-selections.sh`
  - Covers the rofi `@theme` carry and the wlogout preset restore
  - 20 checks, from a sandbox `XDG_CONFIG_HOME` with no session
- `config/hypr/scripts/tests/test-rainbow-borders-menu.sh`
  - Covers the Rainbow Borders indicator and the marker strip
  - 11 checks, from a sandbox `XDG_CONFIG_HOME` with no session
- Marker tests for the four theme pickers
  - `tests/test-kitty-theme-menu.sh`, `tests/test-ghostty-theme-menu.sh`
  - `tests/test-starship-prompt-menu.sh`, `tests/test-zsh-theme-menu.sh`
  - Each asserts the marker never reaches a config, a link or `ZSH_THEME`
  - 20 checks, from a sandbox `XDG_CONFIG_HOME` with no session
- `patches/82-monitors-lua-reset.sh` recovers an upgraded install
  - Removes a `UserConfigs/monitors.lua` that an older version generated
  - Keeps a `monitors.lua.generated-backup-<date>` copy beside it
  - Saved layouts live in `display-layouts.json` and are untouched
  - Runs once, so a layout applied later is never removed
- Lua syntax validation in Quick Settings (`Kool_Quick_Settings.sh`)
  - Automatically validates edited `.lua` files with `luac -p` on editor close
  - Sends desktop notifications for syntax errors, successful check, or if `luac` is not installed
- `scripts/HyprIPC.sh` and `scripts/HyprEventWatch.sh`
  - Socket helpers, plus the event listener the two status modules use
- `patches/60-user-laptops-nonblocking.sh`
  - Removes the blocking `io.popen` calls from an installed `user_laptops.lua`
- `patches/70-user-laptops-refresh-throttle.sh`
  - Adds the layout-refresh throttle to an installed `user_laptops.lua`
- `waybar/configs/Matt-Legacy-config` and `waybar/style/Matt-bright-style.css`
  - A top bar layout built on the project module files via `include`
  - `custom/menu`, `custom/power` and `tray` come from those files
  - `custom/swaync`, `custom/hint`, `custom/keyboard` are icon/text pairs
  - Only the text half of a pair runs a script, so listeners cannot collide
  - The style inlines its gruvbox palette, so it ships as one file
- Multi-monitor display layouts
  - A layout belongs to a monitor set, keyed by device, not by port
  - `SUPER + ALT + D` opens the menu; `SUPER + ALT + W` applies layout `Work`
  - A layout you apply is written to `UserConfigs/monitors.lua`, which Lua loads
  - So a layout survives a reload, a restart and a lid event
  - Per layout: on/off, mode, scale, rotation, position, primary, Waybar bars
  - `nwg-displays` is bridged, and a run you start yourself is imported too
  - The watcher watches nwg's own `monitors.conf` and imports it when it changes
  - A run the menu did not start leaves no pause file, so it is found by name
  - Lid handling stays in `user_laptops.lua`, which reads the same file
  - 568 checks run from JSON fixtures with no monitors attached
- `Monitor Profiles` uses the same layout store
  - From Quick Settings (`SUPER + SHIFT + E`), lists this set's layouts
  - `Monitor_Profiles/*.lua` is offered as a one-way import into the store
- `patches/80-display-layouts.sh` activates the feature on existing installs
  - `copy.sh` only adds missing `UserConfigs` files, so the edits never landed
  - It starts `MonitorWatcher.sh` and adds the two display keybinds
- `config/hypr/scripts/tests/test-lua-syntax.sh`
  - Parses every `.lua` file under the config with `luac -p`
  - One syntax error anywhere takes the whole config load down with it
  - The `UserConfigs` files load through a `pcall`, so that failure is silent
  - It also catches a stray copy of a broken file left in the config tree
  - Reports and passes where `luac` is not installed
- `Monitor_Profiles/Work.lua`, a shipped profile to copy or edit
  - One `preferred` / `auto` / `1` rule per output, matched by port
  - Covers `eDP-1`, `DP-1`..`DP-3`, `HDMI-A-1` and `HDMI-A-2`
  - Apply it from Choose Monitor Profiles, then `SUPER + ALT + W` applies it
  - `preferred` rather than `highres`: the panel's own choice, always usable
- `waybar/configs/TOP-Garuda`, `waybar/style/Garuda.css`, `waybar/launcher.png`
  - A Nord top bar ported from a Garuda Linux Waybar
  - `modules-left` opens with `custom/menu`, the rofi app menu
  - Workspace indicators are numbers (`hyprland/workspaces#numbers`)
  - `modules-right` ends with `custom/power`, the wlogout menu
  - `custom/power` is the project module, pulled in through `include`
  - `custom/menu` is mirrored locally to draw the launcher image
  - It keeps the same rofi action; only `format` differs
  - `launcher.png` sits at the waybar root, where `url()` resolves
  - The style inlines its Nord palette, so it ships as one file

## Updated:

- `docs/HOWTO-Upgrade-Dotfiles.md` says what an upgrade keeps
  - The rofi theme, the wlogout preset and the saved display layouts
  - The `.es.md` translation is kept in sync
- Do not add `require("monitors")` to your Hyprland config
  - `nwg-displays` 0.4.3+ writes a Lua sibling at `~/.config/hypr/monitors.lua`
  - This config never loads that path, so the sibling stays inert on purpose
  - Adding the `require` makes it live and it competes with `monitors.lua`
  - Its own README suggests the line for Hyprland 0.55+; ignore it here
- The display-layout docs no longer say a direct `nwg-displays` run is lost
  - `README-display-layouts.md` and the operational guide cover it instead
- Removed KB default "pc105" from `user_settings.lua`
- `docs/HOWTO-Change-Keybindgs.md` now covers `dispatch(...)` resolution
  - Documents the in-process helper mapping and the native `hl.dsp.*` form
  - Corrects the `["repeat"]` and `dispatch("pin")` examples
  - Notes that `LayoutKeybindDispatch.sh` and `LuaCycleWindow.sh` are gone
  - The `.es.md` translation is kept in sync

## Removed:

- The dead lid close/open paths in `scripts/LidSwitch.sh`
  - Nothing called them: `user_laptops.lua` binds the lid switch itself
  - Close switched the panel off with no external monitor to show the session
  - Open replayed a rule without `disabled = false`, so the panel stayed off
  - `lua/laptop-lid.lua`, the sample that bound them, is now a pointer only
- `scripts/LayoutKeybindDispatch.sh` and `scripts/LuaCycleWindow.sh`
  - Both are replaced by in-process actions in `lua/window_actions.lua`
  - `docs/Keybinds.md` names the in-process actions instead of the scripts
- `scripts/keybinds_parser.py`
  - 528 lines of regex that read the keybind files as text
  - `lua/keybind_index.lua` records every `hl.bind()` in the Lua VM instead
  - `KeyBinds.sh` asks that module to re-render the list before every run
  - No `python3`, no file parsing, and no list left behind by a live change

---

## v2.3.27.7

## Fixed:

- Hyprview layout menu was almost twice as wide as it needed to be
  - Width override added in `select-hyprview-layout.sh`
- `configs/system_keybinds.lua` was out of sync with the `lua/` template
- `cursor:no_hardware_cursors` now defaults to 2 (auto) in `lua/settings.lua`
  - NVIDIA and hybrid systems set 1, VMs set 1 in `lib_detect.sh`
- Keybinds that used legacy dispatcher names silently did nothing
  - Since 0.55 the old hyprlang dispatcher names are not Lua globals, so `hyprctl dispatch resizeactive -50 0` evaluates to `hl.dispatch(resizeactive -50 0)` and errors, while the `hl.dsp.exec_raw("resizeactive -50 0")` path spawned a process named `resizeactive`, which does not exist - both were silent failures
  - Affected `SUPER SHIFT + arrow` (resize), `SUPER ALT + arrow` (swap), `SUPER CTRL + F9..F12` (move workspace to monitor), `ALT + Tab` (bring to top), `SUPER CTRL + J/L/H` (group move) and `SUPER + M` (`splitratio`)
  - Resize and swap now bind native dispatcher objects directly (`hl.dsp.window.resize({ ..., relative = true })` and `hl.dsp.window.swap({ direction })`), the rest get explicit `hl.dsp.*` handlers, and `raw_dispatch_cmd` falls back to `hyprctl dispatch` instead of `hl.dsp.exec_raw` in both `configs/system_keybinds.lua` and `lua/user_keybinds_helper.lua`
- Hold-to-repeat keybinds never repeated
  - The Lua bind option is `repeating`; `["repeat"] = true` is silently ignored, so volume, brightness and the resize binds fired once however long the key was held
- Quick Settings could open a keybind file that Hyprland never loads
  - `resolve_system_keybinds_file()` in `Kool_Quick_Settings.sh` preferred `lua/keybinds.lua`, an orphaned template that `hyprland.lua` does not load, so "Edit System Default Keybinds" edited a file with no effect; `KeyBinds.sh` also passed it to `keybinds_parser.py` first
  - Both now resolve `configs/system_keybinds.lua` first, with `UserConfigs/system_keybinds.lua` and then the old template as last-resort fallbacks

## Added:

- `AGENTS.md` project rules for AI agents
- `config/hypr/lua/window_actions.lua` - in-process replacements for the `float.all.samesize.lua` and `ScrollCycleColumnWidth.sh` helper scripts, with no `hyprctl` calls and no JSON parsing
- `docs/LuaScriptsMigrationPlan.md` - the bash-to-Lua migration plan, verified API notes, work queue and agent handoff completion log

## Removed:

- Dead keybind helper scripts and the orphaned keybind template
  - `scripts/ResizeActive.sh`, `scripts/LuaMoveWindowDirectional.sh`, `scripts/LuaFocusWorkspaceRelative.sh`, `scripts/LuaMoveWindowWorkspaceRelative.sh` and `scripts/LuaFullscreenMaximized.sh` had no live callers
  - `scripts/LuaSwapWindow.sh` (bash + 2 `hyprctl` + a 25-line `jq` overlap test) is replaced by `hl.dsp.window.swap`, which is already a no-op when there is no window in that direction
  - `scripts/float.all.samesize.lua` shelled out to `hyprctl` four times and carried a hand-rolled JSON decoder; it is now `lua/window_actions.lua` running inside Hyprland's Lua VM
  - `scripts/LuaAutoReload.sh` is redundant: Hyprland reloads the Lua config automatically when a file is saved
  - `lua/keybinds.lua` and `lua/keybind_helpers.lua` were never loaded by `hyprland.lua`; they duplicated `configs/system_keybinds.lua` and carried the same legacy-dispatcher bug

## Update:

- To make easier to find I updated descriptions for:
  - waybar restart `SUPER ALT R`
  - Hyprview `SUPER CTRL TAB`

---

## v2.3.27.6

## Fixed:

- `cursor:no_hardware_cursors` was never enabled, even on NVIDIA-only systems
  - `scripts/lib_detect.sh` classifies GPUs from `lspci -k` output, and the AMD vendor match was `amd|advanced micro devices|ati`; the bare `ati` alternative matched the "ati" inside "compatible", and lspci describes every VGA device as "VGA compatible controller"
  - So `has_amd` was 1 on any machine with a VGA device, the "Hybrid GPU detected" branch always won, and `no_hardware_cursors` was forced to 0 - it was never set to 1, so NVIDIA users never got the software-cursor workaround
  - The vendor matches are now word-bounded (`\bintel\b`, `\b(amd|ati)\b|advanced micro devices`), so NVIDIA-only systems take the `no_hardware_cursors = 1` branch while genuine Intel/AMD + NVIDIA hybrids still get 0
- Virtual machines lost the `no_hardware_cursors = 1` tweak
  - `detect_vm_adjust()` only uncommented `WLR_RENDERER_ALLOW_SOFTWARE`; the Hyprlang version also forced `no_hardware_cursors` to 1 for VMs, and that step was dropped when the `.conf` targets were pruned
  - Virtual GPUs (virtio, VMware, VirtualBox) mis-render hardware cursors, so the VM branch now sets `no_hardware_cursors = 1` like the NVIDIA path
  - It runs after `detect_nvidia_adjust`, so a VM with a passed-through NVIDIA GPU ends up enabled as well

---

## v2.3.27.5

## Fixed:

- The Rainbow Borders mode was lost on logout
  - The mode is stored in `~/.config/hypr/UserScripts/rainbow-borders.mode`, but nothing applied it at login, and `RainbowBorders.sh` is a one-shot
  - `scripts/WallustSwww.sh` is the last writer of `general:col.active_border` on every wallpaper/theme change, so it replaced the rainbow border with the Wallust palette and the choice survived only until the next wallpaper change
  - Added `config/hypr/scripts/RainbowBordersStartup.sh`, which reads the mode file and applies the matching script: `rainbow` / `wallust_random` / `gradient_flow` -> one-shot `RainbowBorders.sh`, `low_cpu` -> animated `RainbowBorders-low-cpu.sh` (stopping any previous instance first), `disabled` -> leaves the Wallust border alone
  - It resolves a usable `WAYLAND_DISPLAY` / `HYPRLAND_INSTANCE_SIGNATURE` before calling `hyprctl` and detaches with `setsid`, so it works both from the login hook and from the wallpaper pass
  - `WallustSwww.sh` calls it immediately after its own border write, `Refresh.sh` and `RefreshNoWaybar.sh` delegate to it instead of their own inline Rainbow Borders blocks, and `startup.lua` calls it once for a login where no wallpaper resolves
  - One implementation, so the callers cannot drift apart; with no mode file a present `RainbowBorders.sh` still enables rainbow borders, matching the Quick Settings detection
- Startup commands could run before the session was usable
  - `exec_once` waited only for the Wayland socket and for a Hyprland socket file to exist, but the socket appears before Hyprland has finished coming up, so clients could initialise against a compositor with no outputs yet
  - The readiness gate now also waits for `hyprctl -j monitors` to report at least one output (bounded), replacing the ad-hoc `sleep N` that startup commands needed to work around this
  - Commands are now spawned through `hl.exec_cmd` - the same path the native `exec-once` used - instead of `os.execute`, so GUI clients, tray applets and D-Bus services get the session environment, a clean signal mask and their own session; `&` / `disown` are no longer needed, and the wrapper no longer relies on a login shell (`sh -lc` -> `sh -c`)
  - The per-session marker check uses `test -e`, not `[ -e ... ]`: `hl.exec_cmd` hands the command to Hyprland's exec path, which glob-expands the string, and an unquoted `[` is a character-class glob - so `[ -e <marker> ]` never evaluated as a test and every entry was silently skipped (no marker, no log, no command)
    - Symptom: adding an entry to `UserConfigs/user_startup.lua` appeared to do nothing, and none of the system startup entries (`nm-applet`, `quickshell`, `hypridle`, clipboard watcher, ...) came up either
  - `lua/startup.lua` no longer keeps its own copy of `exec_once`; both startup lists call the shared `lua/user_startup_helper.lua`, so the system and user lists cannot drift apart again
- A terminal autostarted from `UserConfigs/user_startup.lua` could be hidden on the special workspace at login
  - `scripts/Dropterminal.sh --startup kitty` spawns its dropdown and then polls for the window to adopt; when no `kitty-dropterm` window had mapped yet it fell back to "whichever window appeared since launch" - an address set-difference with no class filter
  - At login that fallback ran while the user's own `kitty` entry was starting, so it adopted the plain kitty window, recorded it as the dropdown terminal and moved it to `special:scratchpad`, which looked exactly like the entry never ran
  - The fallback now only accepts a window whose class (or initial class) matches the terminal that was launched - `kitty-dropterm` for kitty, the binary name for anything else - so the plain `kitty` window is left where it opened

## Updated:

- `docs/HOWTO-Add-Apps-To-user_startup.lua` (English and Spanish): documents the readiness gate, the `hl.exec_cmd` spawn path, that `&` / `disown` are unnecessary, and that Rainbow Borders is a Quick Settings mode rather than a startup entry

---

## v2.3.27.4

## Fixed:

- `copy.sh` aborted an express/upgrade run when it was started with a shell other than bash
  - Symptom: `adjust_qt_quick_controls_style:27: no matches found: /usr/lib/*-linux-gnu/qt*/qml`, after which the script exited before copying anything
  - Root cause: `copy.sh` is bash-only (`BASH_SOURCE`, `shopt`, `[[ ]]`, arrays), but it can be launched as `zsh copy.sh --express-upgrade` (or `sh copy.sh` where `sh` is zsh), and zsh treats an unmatched glob as a fatal error (`nomatch`); the Qt QML probes in `adjust_qt_quick_controls_style()` only match on systems that ship those paths
  - `copy.sh` now re-execs itself under bash whenever `BASH_VERSION` is unset, and exits with a clear message if bash is not on `PATH`
  - The Qt QML probes in `scripts/lib_detect.sh` now expand to nothing when they match no path (`null_glob` under zsh, `nullglob` under bash, restored afterwards), so the optional directories are skipped instead of ending the run
  - `config/hypr/scripts/Polkit.sh` carried the same unmatched-glob loop in its Kvantum fallback and was given the same treatment

## Added:

- Bluetooth icon for Blueman windows in the Waybar workspaces module
  - `config/hypr/waybar/ModulesWorkspaces` now maps `blueman-manager` and `blueman-applet` to the Bluetooth icon; both previously fell through to `window-rewrite-default`
  - The `blueman-manager` pattern is `[Bb]lueman-manager` so `blueman-manager` and `Blueman-manager` window classes both match, following the file's convention for other GTK apps such as `[Pp]avucontrol` and `[Ss]potify`

## Removed:

- Dead Hyprlang compatibility code left over from the Lua migration
  - `config/hypr/lua/user_overrides.lua` no longer scans `UserConfigs/*.conf` (`WindowRules.conf`, `LayerRules.conf`) for active rules just to print a "not loaded in Lua mode" warning, and the now-unused `has_active_hyprlang_content()` helper went with it
  - The legacy `UserConfigs/UserKeybinds.conf` importer - which replayed `bind`/`unbind` lines through `hyprctl keyword` when `user_keybinds.lua` was missing - is gone from both `config/hypr/lua/user_overrides.lua` and the shim that `scripts/migrate-hypr-to-lua.sh` generates

---

## v2.3.27.3

## Fixed:

- Pruned the leftover Hyprlang `.conf` plumbing that no longer had a file to act on
  - `WallpaperSelect.sh` dropped `modify_startup_config()`, which rewrote `UserConfigs/Startup_Apps.conf`; live wallpapers are configured in `lua/startup.lua`, where the `mpvpaper` entry is documented
  - `lib_detect.sh` now writes only the Lua targets for the NVIDIA/VM tweaks (`lua/env.lua`, `lua/settings.lua`); the `configs/ENVariables.conf`, `configs/SystemSettings.conf` and `hypr/monitors.conf` seds were dead, and the `Virtual-1` rule they uncommented already ships enabled in `lua/monitors.lua`
  - `lib_prompts.sh` writes the keyboard layout to `UserConfigs/user_settings.lua` and `lua/settings.lua` only; the `UserSettings.conf` and `SystemSettings.conf` steps were no-ops
  - Removed `scripts/fix-systemsettings-lua.sh`, an uncalled one-shot that regenerated `configs/system_settings.lua` from the removed `SystemSettings.conf` (its output is byte-identical to the shipped file)
  - Refreshed stale comments in `TouchPad.sh`, `WallpaperCmd.sh`, `update_WindowRules.sh` and `keybinds_parser.py` that still pointed at removed `.conf` files
- Waybar's terminal / file-manager / btop / nvtop / nmtui clicks did nothing
  - `WaybarScripts.sh` still required `UserConfigs/01-UserDefaults.conf`, which was removed with the other Hyprlang files, so it exited 1 with "Configuration file not found!" and every Waybar action calling it was dead
  - It now resolves `term` and `files` the way the rest of the repo does: `UserConfigs/user_defaults.lua` override, then `lua/user_defaults.lua`, then `$TERMINAL` / `$FILE_MANAGER`
  - `--term` (and the `btop` / `nvtop` / `nmtui` payloads) delegates to `LaunchTerminal.sh`, and `--files` to `LaunchFileManager.sh`, so both get the existing installed-terminal / file-manager fallback chains
  - Also dropped the dead `01-UserDefaults.conf` branch from `apply_editor_selection_to_userconfigs()` in `scripts/lib_apps.sh`; the editor default is written to `user_defaults.lua` only

---

## v2.3.27.2

## Fixed:

- Suspend was delayed by ~30s on every suspend, caused by `hypridle`
  - `systemd-logind` logged `Delay lock is active (UID 1000/... PID .../hypridle) but inhibitor timeout is reached`, so logind waited out the whole `InhibitDelayMaxSec` (30s on Ubuntu, 5s upstream) before suspending
  - Root cause: hypridle releases its logind sleep "delay" inhibitor only once `before_sleep_cmd` returns, and `before_sleep_cmd = loginctl lock-session` blocks when the session lock is never acknowledged (a stale `hyprlock` instance had been running for 42 hours)
  - `before_sleep_cmd` now runs the lock in the background so the inhibitor is released immediately; `patches/25-hypridle-suspend-delay.sh` migrates existing installs and leaves a custom command untouched
  - Duplicate `hypridle` daemons were also possible: each instance registers its own sleep delay inhibitor, so two doubled the suspend path's inhibitor handling
  - `startup.lua` now calls `HypridleStartup.sh`, which starts hypridle once (preferring the systemd user unit) and terminates any stray duplicate daemon, keeping the unit-owned instance
  - `patches/25-hypridle-suspend-delay.sh` installs that helper and runs it once, so an already-running session is de-duplicated without a re-login

---

## v2.3.27.1

## Fixed:

- swaync path wasn't corrected on updates
  - Added patch to copy.sh to fix on updates
- Waybar kept the old wallpaper's colors after a wallpaper change
  - Root cause: Waybar only re-reads its stylesheet when it is reloaded, and `WallustSwww.sh` never signalled it - the script rewrote `colors-waybar.css` and applied the Hyprland borders in-process, so borders followed the wallpaper while the bar stayed on the previous palette
  - Most visible on the automatic wallpaper rotation (`WallpaperAutoChange.sh` -> `RefreshNoWaybar.sh`, which deliberately does not touch Waybar) and on `WallpaperEffects.sh` / `WallpaperDaemon.sh`, which ran no refresh at all
  - `WallustSwww.sh` now reloads a running bar once the palette is written (`waybar-msg cmd reload`, falling back to `SIGUSR2`); a missing bar is still left to `WaybarStartup.sh`, and the reload is a signal, not a restart
- Stale Wallust imports in installed Waybar styles could survive updates
  - `copy.sh` refreshes `~/.config/hypr/waybar` (with a stale-path auto-repair), but the menu's update action only pulls the repo and runs patches
  - Added `patches/40-waybar-wallust-import.sh`, which repairs legacy/doubly-nested Wallust `@import` paths in the installed Waybar styles - the same class of breakage swaync had
- Explicit per-output monitor rules were overridden at login and on hotplug
  - `UserConfigs/user_laptops.lua` applied a synthetic "preferred" fallback to every display that was not listed in `UserConfigs/monitors.lua`, and that pass runs last on `hyprland.start` / `monitor.added` / `monitor.removed`, so it silently replaced explicit rules such as `Virtual-1 = 1920x1080@60`
  - `user_laptops.lua` now resolves the user overrides first and falls back to explicit per-output rules from `hypr/lua/monitors.lua`; the system file's wildcards are left to Hyprland's own fallback chain
  - Added `patches/50-monitor-layout-override.sh`, which applies the same change to installed copies (`copy.sh` protects existing `UserConfigs` files) and leaves the file untouched if it does not match the expected layout

## Updated:

- Docs for the Waybar -> `~/.config/hypr/waybar` move and its fallout
  - `docs/HOWTO-Migrate-Waybar-To-Hypr.md` (+ Spanish): correct `@import` depth per file, automatic and manual migration, and why the bar needs a reload to pick up new colors
  - `docs/Patching-UserConfigs.md` now documents that patches may target any user-owned config file, not just `hypr/UserConfigs` / `hypr/UserScripts`

---

## v2.3.27

## Fixed:

- `ghostty` config error at startup
  - Also fixed missing themes
  - Add change to blur setting to patches/
  - Root cause: the shipped default `theme = "Catppuccin Mocha"` is resolved against `~/.config/ghostty/themes` and `share/ghostty/themes`; distros that ship Ghostty without its built-in theme collection (Gentoo, some minimal/Flatpak builds) install neither, so the theme could never resolve
  - Bundled `Catppuccin Mocha` under `config/ghostty/themes/` and install bundled themes into `~/.config/ghostty/themes` on `copy.sh` (user themes are never overwritten)
  - Added `GhosttyThemeGuard.sh`: validates the active theme and falls back to the wallpaper (wallust) colors, or plain defaults, when it cannot resolve, then signals Ghostty to reload. Runs at login from `startup.lua` and is idempotent
  - `Ghostty_themes.sh` now only offers themes that actually resolve on the system
  - Replaced the deprecated `background-blur-radius` with `background-blur` in the shipped configs (Ghostty 1.3 renamed it; the previous intensity is preserved)
  - Set default Ghostty font to `JetBrainsMono Nerd Font Mono` with `Symbols Nerd Font Mono` fallback
  - `patches/20-ghostty-background-blur.sh` migrates existing installs in place, only when the old key is present
  - `patches/21-ghostty-font.sh` updates existing Ghostty configs to use JetBrainsMono Nerd Font Mono and migrates non-standard font references
- Duplicate waybars at startup (still reproducible on Ubuntu and Gentoo)
  - Root cause: a laptop login fires several `monitor.added`/`monitor.removed` events at once
  - Each event ran `LidSwitch.sh refresh`, which fell back to `Refresh.sh` when Waybar was not yet up
  - Those concurrent `Refresh.sh` runs each killed/relaunched Waybar with no shared lock, so both bars survived
  - `WaybarStartup.sh` now owns the Waybar lifecycle and serializes every start/restart on one lock, and gains a `--restart` mode plus a duplicate-instance cleanup
  - `Refresh.sh` delegates to `WaybarStartup.sh --restart` instead of its own unlocked kill+launch
  - `LidSwitch.sh refresh` now coalesces event bursts and only signals a running bar (`SIGUSR2`), starting it via the locked startup script when missing
  - `user_laptops.lua` throttles post-layout refreshes so a login burst collapses into one
- `LidSwitch.sh` used the legacy `hyprctl dispatch dpms on` form
  - The Lua parser rejects it, so DPMS never actually turned on during lid/refresh handling
  - Switched to the `hl.dsp.dpms` dispatcher
- Replaced `io.open` calls with LUA API
  - This prevents hyprland stall when code active
- Mouse zoom guesture causing hyprland to stall
  - Thank you Angel Spano `@jasueh`
- Quickshell `overview` mouse functions restored
  - Thank you to `@nettucui` for the code to fix it
- Wlogout menu too short to display all options
- Another cause of duplicate waybars
- NixOS installed wrong fastfetch config file
- Kitty background color was bright red
- Waybar service not restarting with `Refresh.sh`
- Hyprland-Dock wasn't reliably toggleing on/off
- Improved version detection in `copy.sh`
- Duplicate waybars at startup (still reproducible on Ubuntu and Gentoo)
  - Root cause: a laptop login fires several `monitor.added`/`monitor.removed` events at once
  - Each event ran `LidSwitch.sh refresh`, which fell back to `Refresh.sh` when Waybar was not yet up
  - Those concurrent `Refresh.sh` runs each killed/relaunched Waybar with no shared lock, so both bars survived
  - `WaybarStartup.sh` now owns the Waybar lifecycle and serializes every start/restart on one lock, and gains a `--restart` mode plus a duplicate-instance cleanup
  - `Refresh.sh` delegates to `WaybarStartup.sh --restart` instead of its own unlocked kill+launch
  - `LidSwitch.sh refresh` now coalesces event bursts and only signals a running bar (`SIGUSR2`), starting it via the locked startup script when missing
  - `user_laptops.lua` throttles post-layout refreshes so a login burst collapses into one
- `LidSwitch.sh` used the legacy `hyprctl dispatch dpms on` form
  - The Lua parser rejects it, so DPMS never actually turned on during lid/refresh handling
  - Switched to the `hl.dsp.dpms` dispatcher
- `find` process in `copy.sh` would consume disk and cpu
  - Process now finishes in 0.1ms
- Animations weren't actually changing
- Terminal variable `$term` not properly quoted causing failed starts
- Moved `kitty` config fully to `.config/hypr/UserConfigs`
- Potential issue with `lockscreen.sh` not logging out
  - If hypridle dies status is updated but no lock is enabled
  - Updating weather info is impromved as well
  - No longer killing/restarting hypridle using wayland inhibit instead
    - Keeps hypridle service active
  - Thanks to `Jitendra dara @jitendradara12` for finding this and proposing fix
- New wlogout themes weren't logging out correctly
- Fixed wlogout theme sending notifications at login
- Fixed Hyprsunset staying enabled after reboot and failing to toggle off
  - Switched toggle handling to use `hyprctl hyprsunset` IPC for seamless, flicker-free adjustments
  - Added robust termination helper with `SIGKILL` fallback to prevent stuck processes
  - Fixed Waybar status detection to respect the state file rather than forcing 'on' whenever the daemon is running
  - Added cleanup on startup to ensure lingering processes from previous sessions are reset when disabled
- `ALT + SHIFT` not working to change keyboard layout
  - Updated modifier normalization and keybinds to use canonical modifiers and keys
- Media Key `stop/pause/play` not working
  - Updated `system_keybinds.lua` to fix this
- Fixed black wallpaper on resume or lid open
  - Added post-layout refresh in `user_laptops.lua` and `LidSwitch.sh refresh`
- Fixed Waybar not displaying on external monitor on lid close/open ("space reserved but no bar")
  - Reloads Waybar via `SIGUSR2` after layout shifts to update layer surface coordinates and recreate bars
- Fixed monitor scale fallback in `user_laptops.lua`
  - Uses `default_fallback.scale` / `auto` instead of hardcoding scale 1 so HiDPI/4K laptop displays retain proper scaling
- Fixed `copy.sh` recreating deleted `Startup_Apps.conf`
  - Updated `scripts/lib_apps.sh` to target `user_startup.lua` for `asusctl`, `blueman`, and `ags`
  - Removed obsolete `Startup_Apps.conf` cursor edit from `scripts/lib_detect.sh`
  - Guarded `WallpaperSelect.sh` when `Startup_Apps.conf` is absent
  - Retired obsolete `ensure_keybinds_init` hook for dynamic Lua keybind workflow
- Fixed `awww` to actualy randomize transistions
- Huge delay and HL IPC stall when changing themes
  - Removed hyprlang code and replaced with LUA
- Huge delay and HL IPC stall when changing themes
  - Removed hyprlang code and replaced with LUA
  - Thank you Angel Spano @jasueh
- Custom scripts weren't preserved on updates
- WindowRules weren't being migrated
- Support for `nwg-look` to set theme / icons
  - REMOVED `DarkLight.sh` and `ApplyThemeMode.sh`
  - Working to greatly simplify theming
  - These two features have added many issues / complexities
- Global Theme now persistent
  - Option added to return to wallpaper theme
- Fixed default apps source order
  - User variables now properly sourced before keybinds
- Wallust directory moved to `~/.config/hypr/wallust`
- `swaync` restarted with `SIG1`
  - `swaync` doesn't have a handler for that
  - Added `systemd --user` service and in-place IPC reloads instead
  - Prevents race conditions and service crash loops
  - Thanks to @hyperion-ak for finding and fixing this
- Hardcoded `eDP-1` caused restore from sleep to fail and lose custom settings
- Hardcoded entries in backlight scripts
- TouchPad, keypad, slidepad detection
  - Thanks to @goldyfruit for the fixes
- `copy.sh` tries to update `~/.zprofile`
  - NixOS systems using Home Manager use RO hard links
  - Updated `copy.sh` to handle those and not exit with error
- Shell script lint cleanup — all `*.sh` now pass `shellcheck --severity=error`
- `Polkit.sh` used `local` outside a function
  - Bash rejected it, so the Kvantum QML fallback never ran
  - Now a plain assignment so `QT_STYLE_OVERRIDE=Fusion` is applied when needed
- `Polkit-Diag.sh` never reported override write errors
  - The redirect swallowed the command output, so `Details:` was always empty
- `RofiEmoji.sh` emoji list made the script unparseable
  - `bash -n`, shellcheck and shfmt all failed on it
  - List moved into a quoted here-doc; contents unchanged
- `RofiThemeSelector-modified.sh` re-split theme paths containing spaces
  - Theme flag is now passed as an array instead of a re-split string
- `KeyboardLayout.sh` exit message mixed `$@` inside a quoted string
- GIF previews in `HyprlockWallpaperSelect.sh` and `WallpaperSelect.sh`
  - `"$pic_path[0]"` is now `${pic_path}[0]` so the ImageMagick frame selector is unambiguous

## Updated:

- `copy.sh` properly syncs quickshell apps w/o overwritting user apps/widgets
- `copy.sh` express upgrade copies waybar files now
- Improved `Cliphistory.sh`
  - Fixed quoting issues
  - Improved error and image handling
- Rofi Emoji menu shows most recently used first
  - Thank you `@BenedettiLucca` for the PR
- `kitty.conf` added `remember_window_size no`
  - Kitty v0.49+ split window opens terminal w/o this setting
  - Thanks to `@卄乇尺ㄩ'ㄩ尺` for posting it
- HOWTO doc on changing icons and themes
  - Hard incorrect info on using env variables
- Added check if `wallpaper-bank` already installed and current
  - Thanks to JoshuaRVLS for the fix
- Express upgrade removed redundant questions
  - Text and Visual editors
  - Waybar 12/24hr setting
- Full upgrade removed redundnat questions
  - Restoring hyprlang based configs
- Removed hyprlang code from `hypr/scripts`
- Began removal of hyprlang based config files
- Kitty has a remote exploit current when `enable_remote_acces = yes`
  - It's now disabled by default
- Moved `$HOME/.config/waybar` to `$HOME/.config/hypr/waybar`
  - Updated scripts, and theming
  - `copy.sh` now has check for stale links and updates them
- Keyboard brightness improved across different HW
- TouchPad auto detection of HW
- Waybar backlight detection improved
- Laptop lid switch detection improved with multi-monitor detection
- Made global theme persistent
  - Menu option to disable and go back to theme by wallpaper
- `WindowRules.conf` isn't used in LUA mode
  - Updated file to point to the .lua file
  - Also added WindowRules.conf to the migration process properly
- Moved `~/.config/wallust` to `~/.config/hypr/wallust`
  - Phase 2 of moving out common config dirs for HL

## Added:

- A `UserConfig`, `UserScripts` patch system
  - Will allow important updates w/o overwritting user changes
- `submap` helper to make creating and managing submaps easier
  - Thank you `@Treinator` for the code
- `submap` active indicator in Waybar
  - Hidden when not in use
  - Shows name of the active submap
- Script `Fix-Fedora-45-overview.sh`
  - The QT libs require `quickshell-git` to resolve errors
    - `qs: symbol lookup error: qs: undefined symbol: _ZN23QUntypedPropertyBindingC1EP23QPropertyBindingPrivate, version Qt_6.11_PRIVATE_API`
- Wlogout theme - `hadi493` adapted from `hadi493/wlogout` repo
  - Fully acreditied in source files
- Wlogout theme from `hadi493` but icons from `LordWorm1996`
- `Hyprland - OEM Default animation`
  - A simple low overhead animation from the default LUA file
- `wlogout` themese
  - Thanks to `@Mr-Hasan-Hamid `
    - For the code and examples
    - There is a menu to select a theme `SUPER+CTRL+W`
- Manage User Defaults Menu
  - From Quick Settings menu
    - Set default:
      - Text editor
      - GUI editor
      - File manager (thunar, etc)
      - Default search engine for search keybind
        - Has list of commont search engines pulldown
        - Not all use same search format in URL
    - Validates apps are installed
- Docs:
  - Bindings
  - Window Rules
  - Adding Apps at startup
  - HowTo Install and Upgrade KoolDots
    - In English and Spanish

---

## v2.3.26.5

- Fixed:
  - Keyboard layout switcher ALT + SHIFT

---

## v2.3.6.4

- Fixed:
  - Missing or incorrect Keybinds
    - Kitty
    - Group/Ungroup
  - Broken keybinds
    - SUPER-R (Column presets scrolling layout)
    - SUPER-G (Group/Ungroup)
    - SUPER-ALT-Mouse Wheel (zoon)
- Added:
  - Docs for overriding GTK and Icon themes
    - In English and Spanish

---

## v2.3.6.3

## Fixed:

- Global Theme now persistent
  - Option added to return to wallpaper theme
- Fixed default apps source order
  - user variables now properly sourced
- Wallust directory move to `~/.config/hypr`
- `swaync` restarted with `SIG1`
  - `swaync` doesn't have a handler for that
  - Added `systemd --user` service instead
  - Also prevents potential race condition
  - Thanks to @hyperion-ak for finding and fixing this
- Hardcoded `eDP-1` caused restore from sleep to fail and lose custom settings
- Hardcoded entries in backlight scripts
- TouchPad, keypad, slidepad detection
  - Thanks to @goldyfruit for the fixes
- `copy.sh` tries to update `~/.zprofile`
  - NixOS systems using Home Manager use RO hard links
  - Updated `copy.sh` to handle those and not exit with error

## Updated:

- Keyboard brightness improved across different HW
- TouchPad auto detection of HW
- Waybar backlight detection improved
- Laptop lid switch detection improved with multi-monitor detection
- Made global theme persistent
  - Menu option to disable and go back to theme by wallpaper
- `WindowRules.conf` isn't used in LUA mode
  - Updated file to point to the .lua file
  - Also added WindowRules.conf to the migraiton process properly
- Moved `~/.config/wallust` to `!/.config/hypr/wallust`
  - Phase 2 of moving out common config dirs for HL

---

## v2.3.26.2

## Fixed:

- DropDownterminal warping you to another workspace
- Changes to `user_keybinds.lua` not loading
- `system_keybinds.lua` wasn't copied on updates
- `togglesplit` in LUA mode
- swaync: missing semicolons in style.css
  - Thx to @hyperion-ak for fix
- Waybar `ModulesCustom` rofi menu called default rofi menu
- Some `.lua` files not copied on updates
- `SUPER+CTRL L/R/U/D` Updated to using existing API
- Added preservation code for `UserConfigs`
  - Fixed migration code was another path to overwrite user files
- Improved handling of RO symlinks in NixOS
- Hypridle updated for LUA commands
- Thanks to @goldyfruit
  - He found four issues and filed them, including how to fix
    - `LuaAutoReload` did not stop when it receives SIGTERM on the polling path.
    - `MonitorProfile` overwrote `monitors.lua`
    - Changes to workspace layouts wasn't persistent
    - Animation selected not loading in LUA config
    - Also some animation files had invalid settings
- KB layout settings not set in `user_settings.lua`
  - Added: Prompts for KB variant and model

## Updated:

- Improved weather units control.
  - Now has system wide variable
  - The Toggle Waybar Units now reads current value
  - Change value restarts systemd environment variable

## Added:

- More defensive code for migration to lua
- More examples in `.config/hypr/UserConfigs/user_keybinds.lua`
  - Showing how to add or rebind keybinds

---

## v2.3.26.1

## Fixed:

- Added preservation code for `UserConfigs`
  - Fixed migration code was another path to overwrite user files
- `copy.sh` was overwritting `UserConfigs/monitor.lua`
- On upgrade waybar config/style got reset (fix 2)
  -Eliminated possible race condition in `awww-daemon`
- Thanks to: @hyperion-ak for the fixes
- Removed dead code from `initial-boot.sh`
  - Thanks to @silesai
- LCD keyboard brightness controls
- Gestures fix 2
  - `copy.sh` was overwritting gesture changes
- Race condition in `awww-daemon` caused it to crash
  - Changed `break 2` to just `break`
  - Fix is applied with `copy.sh` on updates
- Some users reported only light mode
  - Fixed `LightDark.sh` script
- Improved handling of user started apps
- `startup.lua` wasn't calling `LuaAutoReload.sh`
- Fixed user defaults
  - Setting `nautilus` as file manager still called Thunar
- Couldn't exit specialworkspace
- Waybar config getting changed on each boot
- Gestures in LUA workflow
- Fixed Quick settings not opening system keybinds file

## Added:

- Added keybinds to increase/decrease brightness
  - `CTRL+ALT+`` the `-/+` keys
- `.luarc.json` file to the LUA subdirs
  - Some editors will report `undefined global hl`

## Updated:

- Re-added laptop keybinds for brightness

---

## v2.3.26

## Added:

- `docs/HOWTO-Upgrade-Dotfiles.md`
- Spanish translation: `docs/HOWTO-Upgrade-Dotfiles.es.md`
- `nwg-dock-hyprland` that themes with wallpaper
- LUA script `float.all.samesizze.lua`script
  - `SUPER + CTRL + SPACE` to activate
  - sets the sizes based on number of windows and resolution
  - Note: Only works in LUA worklow, not Hyprlang
- Documented `fastfetch` `config.json` on how to add graphical logo
- `ToggleOpactiy.sh`

- Selecting `zsh` now updates `.zprofile`

  ```sh
    if [ -f /etc/profile ]; then
       source /etc/profile
    fi
  ```

  - This should help resolve flatpak apps not showing in rofi menu
  - Thanks to `@jfabernathy` for finding it

- `docs/Keybinds.md` a layout of all the default keybinds
- Option for event drive disable of eDP-1 on lid close
- `kitty.conf` and `ghostty/config` are now saved to `UserConfigs` directory
  - If file is gone or can't be read it will fall back to defaults
- `qs-hyprview` an alternative to quickshell `overview`
  - `CTRL-TAB` to activate
  - Has search filter
  - Optional layouts available
    - Edit system keybinds to change the layout
  - Added blur and dimming to layerrules for `qs-hyprview`
  - Sample values for LUA `user_startup.lua` file
- `select-hyprview-layout.sh`
  - Runs rofi menu to select `qs-hyprview` layout
  - Stores value in `.config/hypr/UserConfigs/hyprview-layout.conf`
    - This prevents overwrite on updates

## Fixed:

- On upgrade waybar config/style got reset (fix 2)
- Eliminated possible race condition in `awww-daemon`
  - Thanks to: @hyperion-ak for the fixes
- Removed dead code from `initial-boot.sh`
  - Thanks to @silesai
- Returning from `game mode` didn't restore user decoration values
- `remove master` in `master layout` generate LUA runtime error
- `cava` and `waybar` cava colors weren't syncing with wallpaper
- Logout on powermenu hanging at black screen
- Improved `RofiBeats.sh`, `RofiCalc`, `RainbowBorders-low-cpu`
  - More compatible with LUA and improved hardening
- `OMZ`themes changed. `copy.sh` checks and downloads them
- `copy.sh` didn't replace LUA system files when already in LUA workflow
- Duplicate waybars on Debian Forky+
- `Float-all-windows.sh` in LUA mode no toggles float/tiled
- Typo in change starship prompt menu
- Extra `read` in `build-awww.sh`
- `Toggle-Active-Windown-Audio.sh`
  - Updated to work in LUA workflow
- `Tak0-Per-Window-Switch.sh` for LUA workflow
- `ToggleOpactiy.sh` in LUA workflow
  - Added more levels to opacity
  - Added desktop notficiations
- `ChangeBlue.sh` in LUA workflow need `-r` flag
  - Added levels blur `Disbled, Low, Medium, High, Ultra`
  - LUA workflow the existing bindings didn't work
- Fixed 2nd issue in yazi
- ENV variables not set in LUA workflow
- Logout session not working in LUA workflow
- `togglesplit` in LUA workflow
- Waybar doesn't restart after Dark/Light theme in Debian
  - Thanks to @tomirgang for the fix
- Not all waybar clocks togggled from 12hr/24hr correctly
  - Thanks to @tomirgang for the fix
- `hyprpolkitagent` fails to start at login
  - Patched `Polkit.sh` to check for systemd service
  - It was trying to run the agent twice causing crash
- Fixed `ChangeBlur.sh` to be compatible with LUA workflow
- Waybar fix caused two waybars to start in Debian. Fixed the fix
- waybar startup delayed in Fedora when not using `hyprland-uwsm` session
  - Found several issues with Fedora b/c of `waybar.service` with Fedora
  - Redid the startup sequences
  - Added gated check for `ags` as that was causing errors when not installed
- Updated startup sequence, wallpaper, theme scripts to remove waybar startup delays
- Default LUA startup file updated to match Hyprlang changes made for waybar
- LUA migration script properly edits `~/.config/hypr/UserConfigs/monitors.lua`
- LUA migration script failed to translate disabled monitors to LUA format
  - I.e. for `eDP-1` laptop screens
- Fixed `Spring-Curves.lua`
  - Hyprland v0.56+ changed springs timing
- Fixed `RainbowBorders` script to work with LUA config
- Fixed lua migrate script to force uppercase `SHIFT`
  - LUA API doesn't allow `shift`
- Duplicate keybinds
- `copy.sh` was ovewritting sddm background and wallpaper
  - Also removed prompt for `Hypridle` restore
- Background image in rofi didn't get updated in LUA workflow
- Some animation bezier values out-of-range
  - Fixed both hyprlang and lua config files

## Updated:

- Added bottom margin to `nwg-dock-hyprland`
- `nwg-displays` removed add `Edit monitor config` in quick settings
- Yazi config to support new APIs in current version
  - Backed up old `main.lua` file for older versions of yazi
- Layout menu has current bindings for each layout
- Shortened `waybar` startup time
- `copy.sh`
  - Defaults to LUA on Fresh Install
  - Upgrades and express upgrade now migrate Hyprlang to LUA
  - It will also convert UserConfigs/\*.conf to LUA
- Moved `qs-hyprview` to `alt - tab`
  - Won't conflict with `alt - tab` used in applications
- `copy.sh` to not overwrite all configs on update
  - rofi menu, kitty/ghostty theme, waybar, wallpaper, etc.
  - Also remove restore options for kitty /ghostty
    - Those config files are in UserConfigs now
- Quick Settings menu into submenus and quick links
- Added script to toggle `qs-hyprview`
  - It checks that it's running and if not restarts it
- Quickshell config files now compatible with all debian versions
- QuickShell config files were blocked on Trixie
  - Trixie now supports quickshell, removed block
- QuickShell overview to current version
  - One issue fixed is moving apps between workspaces
  - `overview` has not been updated in this project for a long time

## Changed:

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

## Fixed:

- Disabled LayerRule for swaync
  - Caused execessive blurring of background
- WindowRule for `qcalculate-gtk`
  - Had same rule as `gnome-calculator` needed own sizing
- Hybrid NVIDIA cursor handoff improvements
  - Enables Xcursor fallbacks and optional setcursor refresh on hybrid laptops

## Added:

- Check for existing `KoolDots` installations
  - Distros are now shipping hyprland with LUA workflow
  - Previous `copy.sh` did not disable `~/.config/hypr/hyprland.lua`
  - After KoolDots installation it would not start, resulting in black screen
  - Now checks for this and backs up `.config/hypr` directory
- Rofi menu to select starship prompt
  - Requires that starship is already configured and running
  - The menu is in the Quick Settings Menu `SUPER SHIFT E`
- `config/rofi/config-layout.rasi` menu for Change Layout menu
- `.config/hypr/scripts/kooldots-add-ssh-agent.sh`
  - will create `systemd` user service to store ssh keys
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
    - `SUPER + SHIFT + F` is fullscreen
    - Now works in all layouts
  - Enabled 12 min timer on turning off monitor
    - For a very long that's been disabled by default
    - The suspend option is still disabled
  - Changed `$HOME` to `${XDG_CONFIG_HOME:$HOME}`
    - Compliant with standard especially with `UWSM`

---

- `Hyprlock.conf` and `Hyprlock-1080.conf` were removed, re-added

## v2.3.24

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

- System menu item to toggle 12/24hr waybar clock
  - Under Edit System Settings `SUPER + SHIFT + E`
  - Search for `waybar`
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
