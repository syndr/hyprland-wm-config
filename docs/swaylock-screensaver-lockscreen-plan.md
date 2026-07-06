# swaylock-plugin Screensaver Lockscreen — Hyprland config integration

## Scope of this branch

This branch covers **only the Hyprland configuration** for using
**swaylock-plugin** with a live **xscreensaver "hack"** as the animated lock
background, in place of hyprlock:

- a lock launcher script vendored into `config/hypr/scripts/` (the Xwayland
  wrapper ships in the swaylock-plugin RPM — see below)
- the `config/hypr/hypridle.conf` `lock_cmd` change (+ DPMS-listener gate)
- a **rofi menu to pick the screenhack** (mirroring the wallpaper selector), with
  an optional **preview**, plus a keybind to invoke it
- the lock launcher reads the rofi-selected hack from a persisted state file
- swaylock-awareness in the two places that currently hardcode hyprlock checks
  (`IdleWatchdog.sh`, `lib_detect.sh`)

**Out of scope here** (already done elsewhere):

- **Packaging** — swaylock-plugin + windowtolayer F44 RPMs exist on **COPR
  `syndr/swaylock-plugin`** (built from the `syndr/swaylock-plugin` fork).
  Binaries land in **`/usr/bin`** (on `PATH`); the RPM also ships the Xwayland
  wrapper at **`/usr/libexec/swaylock-plugin/example_xwayland_wrapper.py`** and
  PAM at `/etc/pam.d/swaylock-plugin` (`%config(noreplace)`).
- **rpm-ostree host configuration** — **`~/ultroncore/phalanx`** already layers
  the RPMs + the xscreensaver hacks (incl. the **GL** packages; 301 hacks,
  build-verified) and creates `/var/lib/xkb` via tmpfiles.d. See phalanx
  `docs/adr/provide-swaylock-plugin-screensaver-lockscreen-deps.md` and
  `build/hyprland/build.sh`.

Assume `swaylock-plugin`, `windowtolayer`, `Xwayland`, the xscreensaver hacks,
the RPM wrapper, `/var/lib/xkb`, and `/etc/pam.d/swaylock-plugin` are **already
present** on phalanx `hyprland`-image hosts (after `rpm-ostree update` +
reboot). This branch only wires Hyprland to use them; on hosts *without* the
RPM the lock script silently degrades to hyprlock (see artifact).

> **Hack set / GL caveat:** the phalanx image ships the full collection
> (`xscreensaver-extras`, `-extras-gss`, `-gl-base`, `-gl-extras` — e.g.
> `glmatrix`, `xrayswarm`, …), but **GL performance is unvalidated**: the
> reference deploy (haures) ran 2D hacks only, and `--command-each` runs **one
> Xwayland per output** (4 here). Keep the light 2D default (`xrayswarm`) until
> a GL hack is perf-checked across all monitors.

---

## How locking is wired (why one line covers everything)

All lock triggers funnel through `loginctl lock-session` → hypridle's
`lock_cmd`. So changing that one line covers the **CTRL+ALT+L** and
**SUPER+`grave`** keybinds (via `LockScreen.sh`), the idle-timeout listener, and
before-sleep.

Validated ad-hoc on **haures** (Bazzite-era rpm-ostree host) with `~/.local/bin`
builds; this branch adapts that deployment to the RPM paths and promotes it into
the repo source-of-truth `config/hypr/`. **This host (alastor) tests it after
`rpm-ostree update` + reboot** (the phalanx image already carries the packages).

Deltas vs. the haures ad-hoc deploy, on purpose:

- haures **commented out the DPMS listener** to stop it mis-gating on
  `pidof hyprlock`; here we **extend the gate** instead (see integration
  point 5) so screens still sleep after the timeout.
- haures' `lock_cmd` predates the repo's `IdleWatchdog.sh` spawn; the new line
  **keeps the watchdog**.
- haures selected the hack via a `$HACK` env var; the **state file + rofi
  picker layer is net-new** in this branch (untested until task 10).

---

## Screenhack selection — reuse the rofi-menu config pattern

Mirror the existing wallpaper selector:
`config/hypr/scripts/WallpaperSelect.sh` (note: `scripts/`, not `UserScripts/`;
the keybind references it via the `$UserScripts` var) — `rofi -i -dmenu -config
<theme>`, options built in a `menu()` function (with `Random:`/`Current:`
entries), `choice=$(menu | $rofi_command)` in `main()`, `pidof rofi` guard, and
it **persists the current selection to per-monitor state files**
(`~/.config/hypr/wallpaper_effects/.wallpaper_current_${focused_monitor}` etc.).
Notably it shows **image thumbnails** via rofi `element-icon` (printf
`"%s\x00icon\x1f%s\n"`). Its keybind is `$mainMod W` in
`config/hypr/configs/Keybinds.conf:59` **only** (keybinds are split across
`configs/Keybinds.conf` and `UserConfigs/UserKeybinds.conf` — each bind lives in
ONE file, not both: CTRL+ALT+L is in `configs/Keybinds.conf`, SUPER+grave in
`UserConfigs/UserKeybinds.conf`). rofi themes are `config/rofi/config-*.rasi`.

Build the screenhack picker the same way:

- **`config/hypr/UserScripts/ScreenHackSelect.sh`** (NEW) — `rofi -dmenu` listing
  the hacks, persists the chosen name to a state file, notifies.
  - List from `/usr/libexec/xscreensaver/`, **filtering out non-hack helpers**
    (names starting with `xscreensaver-`, e.g. `xscreensaver-auth`,
    `xscreensaver-getimage*`, `xscreensaver-text` — 9 of them on haures).
  - Optional `. random` entry, like the wallpaper selector's `Random:`.
  - Persist to **`$HOME/.config/hypr/.swaylock_hack`** (runtime state in the
    deployed config only — the repo→`~/.config` copy is one-directional, so it
    never lands in the repo tree; nothing to gitignore. Default applies when
    absent or naming a missing hack).
- **`config/rofi/config-screenhack.rasi`** (NEW; or reuse a simple text dmenu
  theme — `config-keybinds.rasi` exists and fits).
- **Keybind** to launch the picker: **`$mainMod SHIFT L`** (verified free in
  both keybind files). Add it in `configs/Keybinds.conf` next to the wallpaper
  selector bind. The lock action stays CTRL+ALT+L / SUPER+grave; the picker is
  a separate bind.

### Preview (bonus) — feasible; Option A chosen for v1

xscreensaver hacks run as a normal **windowed X client** when given a `DISPLAY`
and **no `-root`** — i.e. they open their own window, which appears as a floating
Xwayland window under Hyprland. That enables both approaches below. (Hyprland's
Xwayland must be enabled, which it is by default.)

- **Option A — live preview via rofi custom keybind (v1):**
  rofi exposes the highlighted row on a custom key (`-kb-custom-1`,
  `kb-custom-N` → exit code 10+N). On that key, the picker:
  1. reads the highlighted hack name,
  2. runs it windowed: `setsid env DISPLAY="$DISPLAY"
     /usr/libexec/xscreensaver/<hack>` (no `-root`),
  3. re-opens rofi; a small Hyprland `windowrulev2` floats/sizes/centers the
     preview window. **The X class the hacks set is unverified until the
     packages are installed locally** (task 10) — check with `hyprctl clients`;
     hacks often set class to the hack name. Land the windowrule as a follow-up
     tweak once verified.
  Track the preview PID and kill it on next preview / on rofi close.
  This is the lowest-effort "wow" option.

- **Option B — cached thumbnails (follow-up, mirrors the wallpaper picker):**
  Pre-render a thumbnail per hack and show them as rofi `element-icon`s, just like
  `WallpaperSelect.sh`. A generator script (run once, or via a "regenerate
  thumbnails" menu action) for each hack:
  1. launch it windowed under a (possibly headless) Xwayland/DISPLAY,
  2. grab the window after a moment — e.g. ImageMagick `import -window <wid>
     thumb.png` (needs the X window id via `xdotool search`/`wmctrl`), or `grim`
     of the floating Wayland window region,
  3. kill it; cache to `~/.cache/swaylock-hacks/<hack>.png`.
  Heavier to build but gives the nicest static menu and matches the existing
  icon-based selector. Generation is the fiddly part (window-id capture timing).

Either way the selection persists to `$HACK_STATE` and the lock launcher
consumes it.

---

## Repo integration points (config only — deploys via copy.sh)

`config/hypr/` is deployed to `~/.config/hypr` by `copy.sh` / `scripts/lib_copy.sh`.
New files under `config/hypr/scripts/` and `config/hypr/UserScripts/` are picked
up automatically (`lib_copy.sh` copies `hypr` wholesale, ~L279) and get exec
bits re-applied (`copy.sh` ~L708-709 `chmod +x` both dirs) — nothing extra
needed for deployment.

1. **`config/hypr/scripts/SwaylockScreensaver.sh`** — NEW lock launcher (below).
   The Xwayland wrapper is NOT vendored — the RPM ships it at
   `/usr/libexec/swaylock-plugin/example_xwayland_wrapper.py` (verify exec bit;
   if the RPM installs it non-executable, invoke via `python3 "$WRAPPER"`).
2. **`config/hypr/UserScripts/ScreenHackSelect.sh`** — NEW rofi picker (+ preview).
3. **`config/rofi/config-screenhack.rasi`** — NEW (or reuse `config-keybinds.rasi`).
4. **`config/hypr/hypridle.conf`** — change `lock_cmd` **preserving the
   IdleWatchdog spawn**. Current (line 10):
   ```
   lock_cmd = (pidof hyprlock || hyprlock) & setsid -f $scriptsDir/IdleWatchdog.sh
   ```
   New:
   ```
   # swaylock-plugin with an xscreensaver hack background (see SwaylockScreensaver.sh).
   # Falls back to hyprlock if swaylock-plugin is absent or fails to start.
   lock_cmd = ($scriptsDir/SwaylockScreensaver.sh || hyprlock) & setsid -f $scriptsDir/IdleWatchdog.sh
   ```
   `lock_cmd` is shell-evaluated (the current line already uses `&`, `||`, and
   `$scriptsDir`), so variable expansion is confirmed. Note: haures hardcoded
   the absolute script path — if `$scriptsDir` misbehaves, that's the fallback.
5. **`config/hypr/hypridle.conf` DPMS listener (lines 20-21)** — the gate
   `pidof hyprlock && hyprctl dispatch dpms off/on` never fires when
   swaylock-plugin is the locker, so 4 outputs would render a hack forever.
   **Extend the gate** on both lines: `pidof hyprlock swaylock-plugin && …`
   (animation shows until the DPMS timeout, then screens sleep as today). Do
   NOT copy haures' workaround of commenting the listener out.
6. **`config/hypr/scripts/IdleWatchdog.sh` (~L88-89)** — gates on
   `pidof hyprlock`; make it swaylock-aware the same way (or consciously
   exclude swaylock-plugin from watchdog handling).
7. **`scripts/lib_detect.sh` (~L230)** — installer logic can rewrite `lock_cmd`
   back to `pidof hyprlock || hyprlock`, silently reverting this feature on a
   future `copy.sh` run. Update it (or confirm its trigger can't fire on an
   already-configured install).
8. **Keybind** for the picker (`$mainMod SHIFT L`, `configs/Keybinds.conf`).
   `windowrulev2` for the preview window as a follow-up once the X class is
   verified (Option A).

No change to the existing lock keybinds or `scripts/LockScreen.sh` (they already
call `loginctl lock-session`). `hyprlock*.conf` theme files stay (fallback +
revert).

---

## Artifact: `config/hypr/scripts/SwaylockScreensaver.sh`

Binaries come from the RPM (`/usr/bin`, on `PATH`), so call them by name. Reads
the rofi-selected hack from the state file; defaults to `xrayswarm`. Degrades
silently to hyprlock on hosts without the RPM (multi-distro safe).

```bash
#!/usr/bin/env bash
# /* ---- swaylock-plugin lock screen with an xscreensaver "hack" background ---- */
#
# Invoked by hypridle's lock_cmd (fires for CTRL+ALT+L, SUPER+grave, idle
# timeout, and before sleep -- all via loginctl lock-session).
#
# The hack is chosen with the rofi picker (ScreenHackSelect.sh) which writes the
# name to $HACK_STATE. Available hacks: /usr/libexec/xscreensaver/
HACK_STATE="$HOME/.config/hypr/.swaylock_hack"
HACK_DIR="/usr/libexec/xscreensaver"
# Shipped by the swaylock-plugin RPM (runs Xwayland rooted, execs the hack inside).
WRAPPER="/usr/libexec/swaylock-plugin/example_xwayland_wrapper.py"
DEFAULT_HACK="xrayswarm"

# Hosts without the RPM (non-phalanx installs) keep hyprlock, quietly.
command -v swaylock-plugin >/dev/null || exec hyprlock

# Runs for every lock trigger; never start a second instance.
pidof -q swaylock-plugin && exit 0

HACK="$( [ -r "$HACK_STATE" ] && cat "$HACK_STATE" )"
HACK="${HACK:-$DEFAULT_HACK}"

# Stale state file (hack renamed/removed): fall back to the default hack first.
if [ ! -x "$HACK_DIR/$HACK" ] && [ -x "$HACK_DIR/$DEFAULT_HACK" ]; then
    notify-send -u low "swaylock-plugin" \
        "hack '$HACK' not found -- using $DEFAULT_HACK" 2>/dev/null || true
    HACK="$DEFAULT_HACK"
fi

if [ -x "$HACK_DIR/$HACK" ] && [ -x "$WRAPPER" ]; then
    # --command-each runs one wallpaper instance per output. windowtolayer
    # adapts the Xwayland-hosted hack (via the wrapper) into a layer-shell
    # surface that swaylock-plugin composites as the lock background.
    exec swaylock-plugin --command-each \
        "windowtolayer '$WRAPPER' '$HACK_DIR/$HACK' -root"
fi

# No usable hack/wrapper: still lock (fail safe), just without animation.
notify-send -u critical "swaylock-plugin" \
    "no usable xscreensaver hack in $HACK_DIR -- locking without animation" 2>/dev/null || true
exec swaylock-plugin
```

Note the lock background uses `-root`; the **preview** runs the same hacks
**without** `-root` (windowed).

---

## Background: why these specific pieces (handled by RPM/phalanx, don't re-fix here)

- **Runs on the host** — swaylock-plugin authenticates via PAM against the real
  login and passes its nested compositor to the wallpaper command via an
  inherited fd; neither survives a container. (Don't containerize the runtime.)
- **The fork, not upstream `mstoeckl`** — its `main` carries three fixes the RPM
  includes:
  - **SIGCHLD reset** — swaylock set `SIGCHLD=SIG_IGN`, inherited by the plugin
    tree, so Xwayland's `waitpid()` for `xkbcomp` got `ECHILD` →
    `XKB: Couldn't compile keymap`. Without it the animation never starts.
  - **multi-output use-after-free crash** — `--command-each` on multiple monitors
    could SIGSEGV the locker on a wallpaper timeout.
  - `__DATE__` cosmetic fix.
- **`/var/lib/xkb` (mode 1777)** must exist — seatless Xwayland writes its
  compiled core keymap there; absent on Bazzite. → phalanx tmpfiles.d.
- **PAM** `/etc/pam.d/swaylock-plugin` = `auth include login`. → RPM
  (`%config(noreplace)`).
- **Hacks** in `/usr/libexec/xscreensaver/` (not `/usr/lib/...` as the swaylock
  README shows). 2D + GL sets, layered in the phalanx image.
- **Stock wrapper works** with the SIGCHLD fix — do not reintroduce the obsolete
  `-nokeymap`/debug/strace diagnostic wrappers.
- **Fail-safe is mandatory** — missing hack → plain lock; failed/absent plugin →
  hyprlock; a lock trigger must never no-op.
- **Recovery (document for users):** `Ctrl+Alt+F2` → login → `killall
  swaylock-plugin` → `Ctrl+Alt+F1`. Because of the `|| hyprlock` fallback this
  **lands you in hyprlock** (fail-secure), not an unlocked session — unlock
  there normally.

---

## Tasks (this branch)

1. Add `SwaylockScreensaver.sh` to `config/hypr/scripts/` (JaKooLit header;
   exec bit handled by copy.sh). No wrapper vendoring — RPM path.
2. Add `UserScripts/ScreenHackSelect.sh` (rofi picker) mirroring
   `WallpaperSelect.sh`; filter out `xscreensaver-*` helpers; persist to
   `~/.config/hypr/.swaylock_hack`; optional `. random`.
3. Implement **preview** Option A (live). `windowrulev2` for the preview window
   as a post-install follow-up (X class unverified until packages land).
4. Add `config/rofi/config-screenhack.rasi` (or reuse `config-keybinds.rasi`).
5. Add the picker keybind `$mainMod SHIFT L` in `configs/Keybinds.conf`.
6. Update `config/hypr/hypridle.conf`: `lock_cmd` (keep IdleWatchdog spawn) +
   extend the DPMS-listener gate to `pidof hyprlock swaylock-plugin`.
7. Make `scripts/IdleWatchdog.sh` (~L88-89) swaylock-aware.
8. Update `scripts/lib_detect.sh` (~L230) so it can't rewrite `lock_cmd` back
   to hyprlock on reinstall.
9. Docs: README/CHANGELOG — picking a hack (keybind), preview, recovery (lands
   in hyprlock).
10. Verify on this host (alastor) after `rpm-ostree update` + reboot: pick a
    hack via rofi (with preview; confirm the X window class for the
    windowrule), lock via keybind, confirm render on all 4 outputs (incl. a GL
    hack perf check), confirm DPMS-off fires while locked, confirm the hyprlock
    fallback on a host/path without `swaylock-plugin`.

Dropped from earlier drafts: gitignore task (repo→`~/.config` copy is
one-directional; runtime state never enters the repo tree) and the
copy-mechanism task (exec bits + new-file pickup verified by design —
`lib_copy.sh` ~L279, `copy.sh` ~L708-709).

---

## Remaining verifications (post-install, task 10)

- **X window class** the hacks set when windowed — needed for the preview
  `windowrulev2` (and Option B thumbnail capture, if pursued).
- **GL perf** across 4 outputs before promoting a GL hack to default; until
  then the default stays `xrayswarm` (2D).
- **RPM wrapper exec bit** — if `/usr/libexec/swaylock-plugin/
  example_xwayland_wrapper.py` ships non-executable, switch the script to
  `python3 "$WRAPPER"`.

## References / related work

- swaylock-plugin fork (RPM source): `git@github.com:syndr/swaylock-plugin.git`
  (`main`) — fixes + `contrib/build-env.sh` + expanded README.
- COPR packages: `syndr/swaylock-plugin` (`swaylock-plugin`, `windowtolayer`).
- windowtolayer (upstream): `https://gitlab.freedesktop.org/mstoeckl/windowtolayer`.
- rpm-ostree host config: `~/ultroncore/phalanx` — see
  `docs/adr/provide-swaylock-plugin-screensaver-lockscreen-deps.md` and
  `build/hyprland/build.sh` (COPR enable, RPM + xscreensaver GL layering,
  tmpfiles.d for `/var/lib/xkb`).
- rofi-menu pattern to mirror: `config/hypr/scripts/WallpaperSelect.sh`.
- Reference ad-hoc deployment (validated live): host **haures** —
  `~/.config/hypr/hypridle.conf`, `~/.config/hypr/scripts/SwaylockScreensaver.sh`,
  `~/.config/hypr/scripts/xwayland_wrapper.py`,
  `~/Downloads/setup-swaylock-plugin.sh`. (Uses `~/.local/bin` builds, env-var
  hack selection, and a commented-out DPMS listener — superseded by this plan
  as described above.)
