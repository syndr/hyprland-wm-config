# Enable the uconsole-battery CPU profile menu from the waybar generator

## Status

Accepted — 2026-11-09. Implemented on branch `feat/uconsole-battery-cpu-menu`
(stacked on `feat/upstream-v2.3.28-lua`).

## Context

The Greenscreen bar shows the battery through `custom/uconsole-battery`, whose
script comes from the `uconsole-tweaks` package. From 0.6.0 that script can
also show and select the CPU governor profile, but only where `uconsole-sleep`
1.8 or newer is installed: its `sleep-cpu-governor` service owns the governor
and takes a per-boot profile request.

Selection is a waybar popup menu, which needs three keys on the module
(`menu`, `menu-file`, `menu-actions`). Waybar reads those statically, and the
module's JSON output cannot add a menu at runtime, so the keys have to be in
the config or not.

- The `uconsole-tweaks` package cannot put them there. Its installer runs as
  root and does not own, or know the location of, a user's waybar config.
- Shipping the keys unconditionally in the templates would give every host
  without `uconsole-sleep` a left-click menu whose items only raise a "needs
  uconsole-sleep" notification.
- This repo already generates the live config: `GenerateWaybarGreenscreen.sh`
  renders `[TOP] Greenscreen Auto` from the three tier templates on every
  refresh, layout change and install.

## Decision

The generator enables the menu, and only when it would work.

1. Each tier template carries a marker **comment**,
   `// @UCONSOLE_BATTERY_CPU_MENU@ …`, inside its `custom/uconsole-battery`
   block. Being a comment, it leaves a template valid when used directly or
   copied by the generator's wide fallback.
2. The generator asks the package for the keys:
   `uconsole-battery --waybar-menu-snippet --if-available`. That command
   prints the keys, comma-terminated, and exits 0 only when `uconsole-sleep`
   and the package's menu file are installed; otherwise it prints nothing and
   exits non-zero. A missing or older `uconsole-battery` behaves the same as
   "not available".
3. When keys come back, the generator replaces the marker line with them.
   When none do, the marker line passes through and the module is unchanged.

The keys, the menu file path and the menu's commands stay owned by
`uconsole-tweaks`. This repo holds only the marker and the substitution.

## Consequences

- Installing `uconsole-sleep` ≥ 1.8 and `uconsole-tweaks` ≥ 0.6.0, then
  refreshing waybar or re-running the installer, turns the menu on; removing
  `uconsole-sleep` turns it off at the next refresh. No per-host config edit.
- A cross-repo contract now exists: the option name
  `--waybar-menu-snippet --if-available`, its exit status, and its output
  being comma-terminated module keys. It is documented in the battery-gauge
  README of `uconsole-tweaks` under "For config generators". A change there
  must keep the failure mode "no output, non-zero exit".
- Left click on the battery module is reserved for the menu on hosts where it
  is enabled. Middle and right click keep their bindings.
- The generator runs one extra short command per render. Hosts without
  `uconsole-battery` skip it.
- Selecting `[TOP] Greenscreen` (or a narrow tier) directly, without the
  generator, gives the module without the menu.
