# Generate hypridle.conf from IdleSettings.conf

## Status

Accepted — 2026-08-29. Implemented on branch `feat/idle-policy-generator`.

Supersedes **Decision 5 (DPMS policy)** of
[Adopt the swaylock-plugin xscreensaver screensaver lockscreen](adopt-swaylock-plugin-screensaver-lockscreen.md).
The rest of that ADR stands.

## Context

`config/hypr/hypridle.conf` accumulated six listeners whose timeouts are
absolute seconds counted from the last input event: `15`, `570`, `600`, `605`,
`1200`, `1800`. Nothing in the file says that `1800` means "lock at 600, then
animate for 1200", so every change meant re-deriving the whole schedule by
hand, and the interleaving of hyprlock-gated and swaylock-gated listeners made
it worse.

Three forces made that untenable:

- **Per-install tuning had almost no surface.** `UserConfigs/IdleSettings.conf`
  exposed three knobs (`KOOL_IDLE_DPMS_OFF`, `KOOL_IDLE_NAG`,
  `KOOL_IDLE_LOCK_TIMEOUT`), applied by `adjust_idle_dpms_policy` doing awk
  block-surgery and `sed` line-rewrites on the shipped file at deploy time.
  Adding a knob meant adding another rewrite pass; the screensaver window and
  the blank delay were not reachable at all.

- **Settings drifted instead of being preserved.** `hypridle.conf` was in
  `FILES_2_RESTORE`, so an upgrade restored the user's copy over the release's.
  That preserved edits but froze the file: releases could never fix anything in
  it, which is why `migrate_hypridle_lock_cmd()` had to exist as a targeted
  `sed` for the one line that absolutely had to change. Hosts ended up with
  configs that were neither the release's nor knowingly theirs.

- **Portable hardware needs two policies.** On the ClockworkPi uConsole a
  10-minute leash and a 20-minute animated lockscreen are fine on the desk and
  wasteful on battery. hypridle has no conditional timeouts and no reload
  signal.

Separately, `swaylock-plugin` turns out to have **no DPMS handling at all**. It
forwards the plugin client's buffers straight through (`forward.c`), so only
clients that draw on `wl_surface::frame` are throttled when the compositor
stops presenting. An xscreensaver hack under Xwayland + `windowtolayer` renders
on its own clock and keeps going at full rate with the panel dark — the
screensaver was quietly one of the most expensive things an idle handheld could
be doing. Decision 5's "give the screensaver a 20-minute window" was written
assuming the dark stretch afterwards was free. It is, only because the panel is
off; the hack itself never stopped.

## Decision

1. **`hypridle.conf` becomes a generated artifact.**
   `scripts/GenerateHypridle.sh` renders it from `UserConfigs/IdleSettings.conf`,
   which becomes the single tuning surface. The generated file carries a
   DO-NOT-EDIT banner and a header table of the derived schedule, so it stays
   readable without being authoritative. The repo keeps a rendered-with-defaults
   copy checked in so an ungenerated deploy still works.

2. **Knobs are relative and named; the generator does the arithmetic.**
   `KOOL_IDLE_LOCK_TIMEOUT_*`, `KOOL_IDLE_WARN_LEAD`, `KOOL_IDLE_DPMS_DELAY_*`,
   `KOOL_IDLE_SCREENSAVER_*`. The post-lock listeners are emitted as
   `lock + window`; listeners are sorted by timeout so the file reads as a
   timeline. Legacy un-suffixed keys still seed both profiles.

3. **AC and battery are separate rendered profiles, not gated listeners.**
   The alternative — emitting both an AC and a battery listener for each event,
   each gated on `OnBattery.sh` — needs no daemon, but doubles the listener
   count and makes the generated file as hard to read as the hand-written one
   it replaces. Instead `IdlePowerWatch.sh` blocks on udev `power_supply`
   uevents, re-renders on an actual AC/battery flip, and reloads hypridle.
   Accepted cost: a reload restarts hypridle and resets every idle timer, and a
   listener whose battery timeout has already elapsed does not fire
   retroactively when you unplug part-way through an idle stretch.

4. **A reload requested while the session is locked is deferred until unlock.**
   Restarting hypridle mid-lock would re-arm the blank window from zero and
   light the panel back up. `IdlePowerWatch.sh` renders immediately but holds
   the reload; `Hypridle.sh reload` is a no-op when hypridle is not running, so
   it cannot undo the waybar idle-inhibit toggle.

5. **The screensaver is stopped, not just hidden, when the panel is dark.**
   All DPMS transitions this config drives go through `ScreenPower.sh`, which
   pairs `hyprctl dispatch dpms` with `ScreensaverPause.sh`.

   **SIGSTOP on the child's process group, not SIGKILL.** swaylock-plugin
   re-runs its command whenever the client disconnects (`client_destroyed()` →
   `run_plugin_command(..., "restarting")`), so killing the hack respawns it.
   Stopping is safe against the "client failed to redraw → permanent
   clientless solid-colour fallback" path, because that 4-second timer arms
   only at output creation (`main.c:299`) and on size-change configures
   (`main.c:389`) — never periodically. swaylock-plugin spawns its child with
   `posix_spawn`'s setsid flag, so the hack, Xwayland and `windowtolayer` share
   one process group distinct from the locker's, and signalling that group
   pauses the tree without touching the locker. Resume is unconditional and
   runs from an `EXIT` trap, so a stopped process tree cannot be orphaned.

6. **A polling fallback covers screen-off the compositor never sees.**
   On the uConsole the power key parks the panel through `uconsole-sleep` at
   the DRM/backlight level while Hyprland still believes its outputs are lit
   and keeps handing out frame callbacks. `ScreensaverPause.sh watch` samples
   `hyprctl monitors` and `/sys/class/backlight/*/bl_power` every 5s, but only
   while a locker is running — negligible next to a GL hack.

7. **The installer stops restoring `hypridle.conf`.** It leaves
   `FILES_2_RESTORE`, and on the first managed upgrade the backed-up copy is
   parked as `hypridle.conf.pre-managed` rather than restored.
   `KOOL_IDLE_MANAGED=0` opts out entirely: the generator is skipped, the
   legacy awk/sed path (`adjust_idle_dpms_policy_legacy`) runs instead,
   `hypridle.conf` is restored from backup as before, and
   `IdlePowerWatch.sh` exits at startup. `run_post_upgrade_audit` warns when a
   managed host's deployed `hypridle.conf` lacks the generator banner, which is
   the signature of a stale file having been restored over the top.

## Consequences

### Positive

- Every timeout is a named, documented key in one user-owned file that survives
  upgrades, and releases can change the *structure* of the idle policy again
  without fighting a preserved file.
- Battery gets a genuinely tighter policy (5-minute lock, 2-minute screensaver
  window against 15 and 20 on AC) without a second config format.
- The screensaver stops costing power the moment the panel goes dark, on every
  path this config controls plus the out-of-band power-key path.
- `migrate_hypridle_lock_cmd()` becomes dead weight on managed hosts — the
  generated file always has the right `lock_cmd`.

### Negative

- A host that had hand-edited `hypridle.conf` silently stops using that file.
  Mitigated by `hypridle.conf.pre-managed`, the deploy-time notice, the audit
  check, and the `KOOL_IDLE_MANAGED=0` escape hatch — but it is still a
  behavior change on upgrade, and the *content* of those edits is not migrated.
- Plug/unplug restarts hypridle, resetting idle timers. Frequent charger
  cycling therefore delays an auto-lock.
- `IdlePowerWatch.sh` is another long-lived session process, and it depends on
  `udevadm monitor` being usable unprivileged.
- The pause watcher polls. It is bounded (only while locked, 5s) but it is
  polling, and it reads a `/sys/class/backlight` path that not every host has.
- Two escalators can now overlap on uConsole hosts: `KOOL_IDLE_NAG=1` plus
  `uconsole-sleep`'s `sleep-idle-alert.service`. Documented in
  `IdleSettings.conf`; not enforced.

## References

- `config/hypr/scripts/GenerateHypridle.sh`, `IdlePowerWatch.sh`,
  `ScreenPower.sh`, `ScreensaverPause.sh`, `lib_idle_settings.sh`
- `config/hypr/UserConfigs/IdleSettings.conf`
- `scripts/lib_detect.sh` (`adjust_idle_dpms_policy`,
  `adjust_idle_dpms_policy_legacy`), `scripts/lib_copy.sh`
  (`idle_policy_is_managed`, `park_hypridle_backup`), `scripts/lib_audit.sh`
- swaylock-plugin: `main.c` (`run_plugin_command`, `client_destroyed`,
  `setup_clientless_mode`, `output_redraw_timeout`), `forward.c`
  (`nested_surface_frame`, `nested_surface_commit`)
