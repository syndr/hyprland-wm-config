# Adopt the swaylock-plugin xscreensaver screensaver lockscreen

## Status

Accepted — 2026-07-05. Implemented and live-verified on a 4-output Hyprland
workstation (alastor) through 2026-07-07 on branch
`feat/swaylock-screensaver-lockscreen`; the tooling was subsequently upstreamed
(see Decision 7), leaving this repo with thin wrappers.

Supersedes the original planning document
(`docs/swaylock-screensaver-lockscreen-plan.md`, removed) that this ADR was
distilled from.

## Context

The lock screen was hyprlock: functional, static. xscreensaver ships ~300
animated "hacks", and the `syndr/swaylock-plugin` fork of swaylock can run an
arbitrary wallpaper command per output as the lock background
(`--command-each`), adapting X11 hacks via `windowtolayer` + a packaged
Xwayland wrapper. An ad-hoc deployment on haures proved the stack works; this
repo needed a first-class, deployable integration.

Constraints that shaped the design:

- **A lock trigger must never no-op.** All triggers funnel through
  `loginctl lock-session` → hypridle's `lock_cmd`, so one line covers keybinds,
  idle timeout, and before-sleep — but that line must be fail-safe.
- **Not all hosts have the packages.** The config deploys to multiple machines
  (and other people's distros); phalanx `hyprland`-image hosts get
  swaylock-plugin/windowtolayer/hacks from the image (see the phalanx ADR
  `provide-swaylock-plugin-screensaver-lockscreen-deps.md`), others may have
  nothing.
- **hypridle timeouts count from last activity, not from lock**, which
  constrains how DPMS-off can coexist with a screensaver that should be
  visible for a while.
- **Some hosts must never DPMS-off** (multi-monitor rigs whose outputs don't
  reliably wake); the installer already had per-host idle-policy knobs
  (`KOOL_IDLE_DPMS_OFF`, `KOOL_IDLE_NAG` in `UserConfigs/IdleSettings.conf`).
- The installer (`copy.sh` / `scripts/lib_*.sh`) restores user-owned files
  (`hypridle.conf`, `UserScripts/`) from backup on upgrades and skips existing
  config dirs in express mode — a feature that changes `lock_cmd` and adds new
  config files must survive that.

## Decision

1. **swaylock-plugin becomes the locker where present; hyprlock stays the
   fallback everywhere.** `lock_cmd = ($scriptsDir/SwaylockScreensaver.sh ||
   hyprlock)`. The launcher degrades: picked hack → default hack (`xrayswarm`,
   2D — GL is heavier with one Xwayland per output) → plain swaylock-plugin →
   hyprlock → nonzero exit for the `||` chain. Recovery from a wedged locker
   (TTY → `killall swaylock-plugin`) lands in hyprlock: fail-secure, never
   unlocked. `hyprlock*.conf` stays shipped.
2. **Hack selection is a rofi picker + a persisted state file**
   (`~/.config/hypr/.swaylock_hack`), mirroring the wallpaper-selector pattern.
   `SUPER SHIFT L`; rows carry a screenshot thumbnail + the hack's one-line
   description from the xscreensaver config XMLs (both searchable); `Alt+P`
   live-previews the highlighted hack windowed (picker stays closed until the
   preview window closes); `Alt+C` opens the per-hack flags file; `. random`
   entry. Preview windows float via a title-matched windowrule
   (`.*from the XScreenSaver.*` — the X class is per-hack, the title phrase is
   the stable handle; Hyprland regexes full-match).
3. **Thumbnails are generated locally**, not fetched: each hack runs briefly on
   a headless Xvfb display and one frame is captured with ImageMagick
   (jwz.org's gallery 403s non-browser clients, and local shots match the
   installed hack versions). Cache: `~/.cache/screenhack-shots/`.
   A dying hack degrades the lockscreen to its own screenshot via `--image`
   instead of swaylock's blank gray; all other fallback theming is standard
   swaylock config (`~/.config/swaylock/config`).
4. **Per-hack tuning flags** live in `~/.config/swaylock-screensaver/hacks.conf`
   (`<hack> <flags...>`, `*` line applies to all), honored by both the
   lockscreen and the preview so previews match reality. A rejected flag makes
   the hack exit — the session still locks, on the screenshot fallback.
5. **DPMS policy:** dedicated swaylock-gated listeners give the screensaver a
   ~20-minute window after lock before screens power off (hyprlock keeps its
   quick-off behavior); hosts with `KOOL_IDLE_DPMS_OFF=0` strip every dpms-off
   listener at deploy time and run the screensaver indefinitely. The
   hyprlock-only pidof gates in `IdleWatchdog.sh` and the DPMS listeners were
   extended, not bypassed.
6. **The installer must not undo the feature.** `adjust_idle_dpms_policy`'s
   nag-strip preserves whatever locker is configured; express upgrades migrate
   a restored stock `lock_cmd` to the launcher
   (`migrate_hypridle_lock_cmd()`, idempotent, custom lines preserved) and
   copy release-new files into otherwise-preserved config dirs (`cp -rn`).
7. **The tooling's canonical home is the swaylock-plugin fork**, not this repo.
   It was written extraction-friendly (env-overridable paths, no `~/.config/hypr`
   assumptions in core logic), then upstreamed to `contrib/screensaver/` (MIT,
   fork PR #7), packaged as `swaylock-plugin-screensaver` (COPR RPM subpackage
   + Debian package), and layered into the phalanx image (phalanx PR #40).
   This repo's three scripts (`scripts/SwaylockScreensaver.sh`,
   `UserScripts/ScreenHackSelect.sh`, `UserScripts/ScreenHackShots.sh`) are
   now **thin wrappers** that pin this config's paths (state file, rofi theme,
   thumbnail cache, kitty, hyprlock fallback) and exec the packaged tools —
   future screensaver features belong in the fork.

## Consequences

### Positive

- Animated lockscreen on every phalanx host with zero per-host setup; other
  hosts silently keep hyprlock.
- One `lock_cmd` line covers every lock trigger; the fail-safe chain was
  verified at each degrade step, including per-hack flags flowing through the
  real windowtolayer/Xwayland stack.
- Single source of truth for the tooling (fork contrib) shared by any
  swaylock-plugin user; this repo carries ~25-line wrappers instead of ~450
  lines of logic. User state (hack pick, thumbnails, hacks.conf) survived the
  wrapper cutover unchanged.

### Negative / constraints

- **Cross-repo coupling:** features ship fork → COPR/Release → phalanx image →
  `rpm-ostree update` + reboot before the wrappers see them. A wrapper-side
  env knob rename must track the fork.
- **GL perf across 4 outputs is unjudged** — the default stays 2D `xrayswarm`;
  GL hacks are opt-in via the picker.
- The express-upgrade preservation model means **hosts with a hand-customized
  `hypridle.conf` keep their own DPMS policy**; only the stock `lock_cmd` is
  migrated. Deliberate.
- Thumbnails need Xvfb + ImageMagick (in the phalanx image; auto-kicked
  generation notifies and skips elsewhere).

### Verified (task-10 record, alastor)

Lock/unlock end-to-end on 4 outputs (one windowtolayer + hack per output);
preview float rule; `Alt+p`/`Alt+c` conflict-free in rofi; RPM wrapper ships
executable; 292/292 thumbnails generated (7 legitimately black: hacks needing
network/video/image sources); picker/editor flows including the
GUI-editor-vs-terminal and missing-`$VISUAL` fallbacks.

## References

- Fork + canonical tooling: <https://github.com/syndr/swaylock-plugin>
  (`contrib/screensaver/`, its README documents every env knob), PR #7.
- Packages: COPR `syndr/swaylock-plugin` (`swaylock-plugin`,
  `swaylock-plugin-screensaver`, `windowtolayer`); Debian/Ubuntu `.deb`s on the
  fork's GitHub Releases.
- Image side: phalanx `docs/adr/provide-swaylock-plugin-screensaver-lockscreen-deps.md`
  + `build/hyprland/build.sh` (PR #39, #40).
- windowtolayer upstream: <https://gitlab.freedesktop.org/mstoeckl/windowtolayer>.
- Fork-carried fixes this depends on: SIGCHLD reset (Xwayland keymap
  compilation), multi-output use-after-free on wallpaper timeout.
- Pattern mirrored for the picker: `config/hypr/scripts/WallpaperSelect.sh`.
