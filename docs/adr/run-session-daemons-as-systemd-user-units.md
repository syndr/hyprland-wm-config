# Run session daemons as systemd user units

## Status

Accepted — 2026-10-14. Implemented on branch `fix/session-units`. Completes
the intent of #19 (`feat(startup): hand session startup to systemd user
units`), which described these units but did not ship them.

## Context

Every long-lived desktop daemon (wallpaper daemon, waybar, hypridle, nm-applet,
cliphist watchers, quickshell overview, copyq, the polkit agent) used to be an
`exec-once` in `configs/Startup_Apps.conf`. Two forces pushed them out:

- **File-descriptor exhaustion kills exec-once children first.** An
  `exec-once` child inherits Hyprland's *pre-raise* soft `RLIMIT_NOFILE` of
  1024. That is the number the kernel's `too_many_unix_fds()` compares the
  per-user in-flight `SCM_RIGHTS` count against, so once anything in the
  session leaks ~1024 in-flight fds, every fd-passing operation in those
  children fails with `ETOOMANYREFS` and they die, while units with
  `LimitNOFILE=524288` keep working. This took the desktop down daily on the
  laptop from 2026-07-22 until the units were hand-written there on
  2026-08-21.

- **A user-owned file is not a release channel.** #19 moved the remaining
  compositor-state lines into `UserConfigs/Startup_Apps.conf` and stopped
  sourcing the vendor file. But `restore_user_configs` restores that file from
  the user's backup on every upgrade, so the rewritten copy never lands. And
  the units it relied on lived only in `~/.config/systemd/user` on one host.
  The first upgrade on another host (the uConsole, 2026-10-14) came up to a grey
  screen: Hyprland fine, nothing painting.

## Decision

1. **Units ship in the repo** under `config/systemd/user/`, named exactly as
   on that laptop so deploying there is idempotent: `hyprland-session.target`,
   `swww-daemon`, `nm-applet`, `cliphist-text`, `cliphist-image`,
   `quickshell-overview`, `copyq`, `ags`, `idle-power-watch`, plus
   `LimitNOFILE` drop-ins for the distro `waybar`, `hypridle` and
   `plasma-polkit-agent` units. Every service is `WantedBy=hyprland-session.target`,
   `BindsTo=graphical-session.target`, `Restart=on-failure`,
   `LimitNOFILE=524288:524288`.

2. **`hyprland-session.target` is the single attachment point.** It is
   `WantedBy=graphical-session.target` (uwsm starts it) and
   `BindsTo=graphical-session.target` (a plain `hyprland.desktop` session
   starts it directly and drags graphical-session.target up with it).

3. **The installer wires it** (`scripts/lib_units.sh:install_session_units`):
   copies the files, unmasks `waybar`/`hypridle` if a host masked them to stop
   the old double-start, `daemon-reload`, enables the target and each shipped
   unit whose binary exists, `add-wants` the distro `waybar`, `hypridle`,
   `blueman-applet`, and exactly one polkit agent (hyprpolkitagent preferred,
   plasma-polkit-agent fallback, otherwise the vendor `Polkit.sh` path is left
   alone). If a Hyprland session is live it starts the target so the deploy
   takes effect without re-login.

4. **Session bring-up is vendor-owned.** `configs/Startup_Session.conf`
   (deployed every upgrade, never restored) carries the `uwsm finalize` /
   `systemctl --user start hyprland-session.target` line, the environment
   export, `hyprpm reload` and the compositor-state scripts.
   `UserConfigs/Startup_Apps.conf` is the user's apps only.
   `migrate_startup_overlay` strips the now-duplicated lines from a user's
   existing overlay (timestamped backup) on upgrade.

5. **Scripts that touch a daemon go through its unit when one is loaded**
   (`Hypridle.sh`, `Refresh.sh`, `WaybarLayout.sh`, `WallpaperSelect.sh`), and
   fall back to the old pkill/spawn path otherwise.

## Consequences

- Hosts converge on the same unit set; a grey screen after upgrade is caught
  by `run_post_upgrade_audit`, which now checks the target is enabled and
  `waybar`/`hypridle` are not masked.
- Daemon state is inspectable and recoverable with `systemctl --user`
  (`list-dependencies hyprland-session.target`, `--failed`, `journalctl --user -u`).
- Hand-written host-local units (the laptop's `kwalletd6`, `onepassword`, `slack`,
  `lan-mouse`, its `dbus-broker` and `app-graphical.slice` drop-ins) are not
  the repo's business and are left untouched by the `cp -r` deploy.
- `lib_apps.sh`'s `enable_*` helpers still append to the vendor
  `configs/Startup_Apps.conf`; that file is inert, so they are harmless no-ops
  kept for clean upstream merges. The unit installer is the live path.
- A host without `uwsm` depends on the exec-once in `Startup_Session.conf` to
  start the target; if that file is not sourced, nothing paints. The audit
  warns when it is missing from `hyprland.conf`.
