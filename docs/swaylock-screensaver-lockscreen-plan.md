# swaylock-plugin Screensaver Lockscreen — Hyprland config integration

## Scope of this branch

This branch covers **only the Hyprland configuration** for using
**swaylock-plugin** with a live **xscreensaver "hack"** as the animated lock
background, in place of hyprlock:

- a lock launcher script + the Xwayland wrapper, vendored into `config/hypr/scripts/`
- the `config/hypr/hypridle.conf` `lock_cmd` change
- a **rofi menu to pick the screenhack** (mirroring the wallpaper selector), with
  an optional **preview**, plus a keybind to invoke it
- the lock launcher reads the rofi-selected hack from a persisted state file

**Out of scope here** (separate tasks / other repos):

- **Building / packaging** swaylock-plugin and windowtolayer → **F44 RPMs via CI**
  on the `syndr/swaylock-plugin` fork. That is the install path; binaries land in
  **`/usr/bin`** (on `PATH`).
- **rpm-ostree host configuration** — layering those RPMs + the xscreensaver
  hacks (incl. the **GL** packages), creating `/var/lib/xkb`, and the PAM service
  — lives in **`~/ultroncore/phalanx`**.

Assume `swaylock-plugin`, `windowtolayer`, `Xwayland`, the xscreensaver hacks,
`/var/lib/xkb`, and `/etc/pam.d/swaylock-plugin` are **already present** (RPM +
phalanx). This branch only wires Hyprland to use them.

> **Hack set:** phalanx layers the GL packages too (`xscreensaver-gl` plus the
> `-extras`/`-extras-gss` 2D sets), so the full hack collection is available
> (e.g. `glmatrix`, `xrayswarm`, …). Caveat: GL hacks are heavier, and
> `--command-each` runs **one Xwayland per output** (4 here) — sanity-check GL
> performance across all monitors when choosing a default.

---

## How locking is wired (why one line covers everything)

All lock triggers funnel through `loginctl lock-session` → hypridle's
`lock_cmd`. So changing that one line covers the **CTRL+ALT+L** and
**SUPER+`grave`** keybinds (via `LockScreen.sh`), the idle-timeout listener, and
before-sleep. Validated ad-hoc on the live system (Bazzite, rpm-ostree,
4-monitor Hyprland) and currently deployed in `~/.config/hypr`; this branch
promotes it into the repo source-of-truth `config/hypr/`.

---

## Screenhack selection — reuse the rofi-menu config pattern

Mirror the existing wallpaper selector:
`config/hypr/UserScripts/WallpaperSelect.sh` — `rofi -i -dmenu -config <theme>`,
options built in a `menu()` function (with a `. random` entry), `choice=$(menu |
$rofi_command)` in `main()`, `pidof rofi` guard, and it **persists the current
selection to a state file** (`~/.config/hypr/wallpaper_effects/.wallpaper_current`).
Notably it shows **image thumbnails** via rofi `element-icon` (printf
`"%s\x00icon\x1f%s\n"`). Keybinds are in BOTH
`config/hypr/UserConfigs/UserKeybinds.conf` and `config/hypr/configs/Keybinds.conf`
(`$mainMod W`); rofi themes are `config/rofi/config-*.rasi`.

Build the screenhack picker the same way:

- **`config/hypr/UserScripts/ScreenHackSelect.sh`** (NEW) — `rofi -dmenu` listing
  the hacks, persists the chosen name to a state file, notifies.
  - List from `/usr/libexec/xscreensaver/`, **filtering out non-hack helpers**
    (names starting with `xscreensaver-`, e.g. `xscreensaver-auth`,
    `xscreensaver-getimage*`, `xscreensaver-text`).
  - Optional `. random` entry, like the wallpaper selector.
  - Persist to **`$HOME/.config/hypr/.swaylock_hack`** (runtime state — gitignore
    it; default applies when absent or naming a missing hack).
- **`config/rofi/config-screenhack.rasi`** (NEW; or reuse a simple text dmenu
  theme like `config-keybinds.rasi`, or the wallpaper theme if using thumbnails).
- **Keybind** to launch the picker, in both keybind files (free combo, e.g.
  `$mainMod SHIFT L` — verify no conflict). The lock action stays CTRL+ALT+L /
  SUPER+grave; the picker is a separate bind.

### Preview (bonus) — feasible; pick one

xscreensaver hacks run as a normal **windowed X client** when given a `DISPLAY`
and **no `-root`** — i.e. they open their own window, which appears as a floating
Xwayland window under Hyprland. That enables both approaches below. (Hyprland's
Xwayland must be enabled, which it is by default.)

- **Option A — live preview via rofi custom keybind (simplest live):**
  rofi exposes the highlighted row on a custom key (`-kb-custom-1`,
  `kb-custom-N` → exit code 10+N). On that key, the picker:
  1. reads the highlighted hack name,
  2. runs it windowed: `setsid env DISPLAY="$DISPLAY"
     /usr/libexec/xscreensaver/<hack>` (no `-root`),
  3. re-opens rofi; a small Hyprland `windowrulev2` floats/sizes/centers
     `class:^(XTerm|.*xscreensaver.*)$`-style windows (use the actual X class —
     verify with `hyprctl clients`; hacks often set class to the hack name).
  Track the preview PID and kill it on next preview / on rofi close.
  This is the lowest-effort "wow" option.

- **Option B — cached thumbnails (mirrors the wallpaper picker exactly):**
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

Recommend **Option A for v1** (cheap, live, no cache), with Option B as a
follow-up if static thumbnails are wanted. Either way the selection persists to
`$HACK_STATE` and the lock launcher consumes it.

---

## Repo integration points (config only — deploys via copy.sh)

`config/hypr/` is deployed to `~/.config/hypr` by `copy.sh` / `scripts/lib_copy.sh`.

1. **`config/hypr/scripts/SwaylockScreensaver.sh`** — NEW lock launcher (below).
2. **`config/hypr/scripts/xwayland_wrapper.py`** — NEW; the fork's
   `example_xwayland_wrapper.py` verbatim, vendored so the lock doesn't depend on
   a `~/Downloads` clone. (Open question: the RPM may ship this under `/usr/share/`
   — if so, reference that instead.)
3. **`config/hypr/UserScripts/ScreenHackSelect.sh`** — NEW rofi picker (+ preview).
4. **`config/rofi/config-screenhack.rasi`** — NEW (or reuse).
5. **`config/hypr/hypridle.conf`** — change `lock_cmd`:
   ```
   # swaylock-plugin with an xscreensaver hack background (see SwaylockScreensaver.sh).
   # Falls back to hyprlock if swaylock-plugin fails to start.
   lock_cmd = $HOME/.config/hypr/scripts/SwaylockScreensaver.sh || hyprlock
   ```
   (Current: `lock_cmd = pidof hyprlock || hyprlock`.) hypridle does its own
   `$var` substitution; the existing line uses `||` so it IS shell-evaluated and
   `$HOME` should expand — verify, else hardcode the absolute path.
6. **Keybind** for the picker — both keybind files. Optional `windowrulev2` for
   the preview window (if Option A).
7. **gitignore** the runtime hack-state file (and `~/.cache/swaylock-hacks` if B).

No change to the existing lock keybinds or `scripts/LockScreen.sh` (they already
call `loginctl lock-session`). `hyprlock*.conf` theme files stay (fallback +
revert).

---

## Artifact: `config/hypr/scripts/SwaylockScreensaver.sh`

Binaries come from the RPM (`/usr/bin`, on `PATH`), so call them by name. Reads
the rofi-selected hack from the state file; defaults to `xrayswarm`.

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
WRAPPER="$HOME/.config/hypr/scripts/xwayland_wrapper.py"

HACK="$( [ -r "$HACK_STATE" ] && cat "$HACK_STATE" )"
HACK="${HACK:-xrayswarm}"

# Runs for every lock trigger; never start a second instance.
pidof -q swaylock-plugin && exit 0

if [ -x "$HACK_DIR/$HACK" ]; then
    # --command-each runs one wallpaper instance per output. windowtolayer
    # adapts the Xwayland-hosted hack (via the wrapper) into a layer-shell
    # surface that swaylock-plugin composites as the lock background.
    exec swaylock-plugin --command-each \
        "windowtolayer '$WRAPPER' '$HACK_DIR/$HACK' -root"
fi

# Hack missing/unset: still lock (fail safe), just without animation.
notify-send -u critical "swaylock-plugin" \
    "xscreensaver hack '$HACK' not found in $HACK_DIR -- locking without animation" 2>/dev/null || true
exec swaylock-plugin
```

`xwayland_wrapper.py` = the fork's `example_xwayland_wrapper.py` unchanged (runs
`Xwayland` rooted and execs the hack inside it). Note the lock background uses
`-root`; the **preview** runs the same hacks **without** `-root` (windowed).

---

## Background: why these specific pieces (handled by RPM/phalanx, don't re-fix here)

- **Runs on the host** — swaylock-plugin authenticates via PAM against the real
  login and passes its nested compositor to the wallpaper command via an
  inherited fd; neither survives a container. (Don't containerize the runtime.)
- **The fork, not upstream `mstoeckl`** — its `main` carries three fixes the RPM
  must include:
  - **SIGCHLD reset** — swaylock set `SIGCHLD=SIG_IGN`, inherited by the plugin
    tree, so Xwayland's `waitpid()` for `xkbcomp` got `ECHILD` →
    `XKB: Couldn't compile keymap`. Without it the animation never starts.
  - **multi-output use-after-free crash** — `--command-each` on multiple monitors
    could SIGSEGV the locker on a wallpaper timeout.
  - `__DATE__` cosmetic fix.
- **`/var/lib/xkb` (mode 1777)** must exist — seatless Xwayland writes its
  compiled core keymap there; absent on Bazzite. → phalanx.
- **PAM** `/etc/pam.d/swaylock-plugin` = `auth include login`. → RPM/phalanx.
- **Hacks** in `/usr/libexec/xscreensaver/` (not `/usr/lib/...` as the swaylock
  README shows). GL + 2D, once phalanx layers the GL package. → phalanx.
- **Stock wrapper works** with the SIGCHLD fix — do not reintroduce the obsolete
  `-nokeymap`/debug/strace diagnostic wrappers.
- **Fail-safe is mandatory** — missing hack → plain lock; failed plugin →
  hyprlock; a lock trigger must never no-op.
- **Recovery (document for users):** `Ctrl+Alt+F2` → login → `killall
  swaylock-plugin` → `Ctrl+Alt+F1`.

---

## Tasks (this branch)

1. Vendor `SwaylockScreensaver.sh` + `xwayland_wrapper.py` into
   `config/hypr/scripts/` (exec bits; JaKooLit header on the `.sh`).
2. Add `UserScripts/ScreenHackSelect.sh` (rofi picker) mirroring
   `WallpaperSelect.sh`; filter out `xscreensaver-*` helpers; persist to
   `~/.config/hypr/.swaylock_hack`; optional `. random`.
3. Implement **preview** (Option A live preview recommended; Option B thumbnails
   optional). Add a `windowrulev2` for the preview window if needed.
4. Add `config/rofi/config-screenhack.rasi` (or reuse).
5. Add the picker keybind in both keybind files (free combo, no conflict).
6. Update `config/hypr/hypridle.conf` `lock_cmd` (verify `$HOME` expansion).
7. Gitignore the runtime hack-state file (+ thumbnail cache if Option B).
8. Confirm `scripts/lib_copy.sh` carries the new scripts/theme and preserves exec
   bits.
9. Docs: README/CHANGELOG — picking a hack (keybind), preview, recovery.
10. Verify on the live multi-monitor host: pick a hack via rofi (with preview),
    lock via keybind, confirm render on all outputs (incl. a GL hack), confirm
    the hyprlock fallback when `swaylock-plugin` is absent.

---

## Open questions

- **preview approach** — A (live, cheap) vs B (cached thumbnails, matches the
  wallpaper picker's look). Confirm the X window class hacks use, for the float
  `windowrulev2` / thumbnail capture.
- **wrapper sourcing** — vendor `xwayland_wrapper.py` here vs reference an
  RPM-shipped path? Coordinate with the CI/RPM task.
- **picker keybind** — choose a free combo distinct from the lock binds.
- **state-file location/format** — `~/.config/hypr/.swaylock_hack`; ensure
  gitignored.
- **GL default + perf** — confirm a GL hack performs acceptably across 4 outputs
  before making one the default; otherwise keep a light 2D default (xrayswarm).
- **replace vs coexist with hyprlock** — current plan keeps hyprlock as the
  `lock_cmd` fallback. Confirm desired.
- **non-atomic hosts** — repo is multi-distro; this flow assumes the Bazzite
  RPM/phalanx install. Conditional, or documented as Bazzite-only?

## References / related work

- swaylock-plugin fork (RPM source): `git@github.com:syndr/swaylock-plugin.git`
  (`main`) — fixes + `contrib/build-env.sh` + expanded README.
- windowtolayer (separate Rust project, also to be packaged):
  `https://gitlab.freedesktop.org/mstoeckl/windowtolayer`.
- **Install path (separate task):** CI on the fork to build F44 RPMs.
- **rpm-ostree host config (separate repo):** `~/ultroncore/phalanx` (layer RPMs
  + xscreensaver incl. GL, `/var/lib/xkb`, PAM).
- rofi-menu pattern to mirror: `config/hypr/UserScripts/WallpaperSelect.sh`.
- Live ad-hoc host-glue reference: `~/Downloads/setup-swaylock-plugin.sh`.
- Live deployed config (this branch promotes it): `~/.config/hypr/hypridle.conf`,
  `~/.config/hypr/scripts/SwaylockScreensaver.sh`,
  `~/.config/hypr/scripts/xwayland_wrapper.py`.
