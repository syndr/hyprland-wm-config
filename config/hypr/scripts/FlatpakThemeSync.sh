#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Keep Flatpak apps on the desktop theme.
#
# Usage: FlatpakThemeSync.sh [kde-colour-scheme-name]
#
# Flatpak passes the session environment into the sandbox but not the host's
# Qt plugins, so the host-only style variables break or un-theme sandboxed
# apps. This script is the single owner of the fix; the installer and
# DarkLight.sh both call it, and it is safe to run by hand at any time.
#
#  1. A user-level global override:
#     - unsets QT_QUICK_CONTROLS_STYLE (org.hyprland.style is not in any
#       runtime, so Qt-Quick apps abort on it) and QT_STYLE_OVERRIDE (kvantum
#       is not in current KDE runtimes);
#     - selects the KDE platform theme, which is what makes Qt-Widgets apps
#       read their palette from kdeglobals. Runtimes without that plugin
#       ignore the setting;
#     - exposes kdeglobals, ~/.themes and ~/.icons read-only so Qt and GTK
#       apps can load the colours, GTK theme and icons the portal names.
#  2. The active KDE colour scheme written inline into kdeglobals. A sandboxed
#     app cannot resolve `ColorScheme=<name>` to a file, so without the
#     [Colors:*] groups inline it falls back to Breeze Light.
#
# With an argument, that scheme becomes the active one; without, the scheme
# kdeglobals already names is re-inlined.

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
kdeglobals="$config_home/kdeglobals"
requested_scheme="${1:-}"

log() {
    printf '[FlatpakThemeSync] %s\n' "$*"
}

find_scheme_file() {
    local name="$1"
    local dir
    for dir in "$data_home/color-schemes" /usr/local/share/color-schemes /usr/share/color-schemes; do
        if [ -f "$dir/$name.colors" ]; then
            printf '%s\n' "$dir/$name.colors"
            return 0
        fi
    done
    return 1
}

current_scheme_name() {
    [ -f "$kdeglobals" ] || return 0
    awk -F= '
        /^\[/ { group = $0 }
        group == "[General]" && $1 == "ColorScheme" { print $2; exit }
    ' "$kdeglobals"
}

sync_overrides() {
    local args=(
        --unset-env=QT_QUICK_CONTROLS_STYLE
        --unset-env=QT_STYLE_OVERRIDE
        --env=QT_QPA_PLATFORMTHEME=kde
        --filesystem=xdg-config/kdeglobals:ro
    )
    [ -d "$HOME/.themes" ] && args+=(--filesystem="$HOME/.themes:ro")
    [ -d "$HOME/.icons" ] && args+=(--filesystem="$HOME/.icons:ro")

    if flatpak override --user "${args[@]}"; then
        log "global Flatpak override updated"
    else
        log "flatpak override failed; Flatpak apps may be unthemed or fail to start"
        return 1
    fi
}

sync_kdeglobals() {
    local name="$requested_scheme"
    local scheme_file tmp

    [ -n "$name" ] || name="$(current_scheme_name)"
    if [ -z "$name" ]; then
        log "no KDE colour scheme set; kdeglobals left alone"
        return 0
    fi
    if ! scheme_file="$(find_scheme_file "$name")"; then
        log "colour scheme '$name' not found; kdeglobals left alone"
        return 0
    fi

    mkdir -p "$config_home"
    [ -f "$kdeglobals" ] || : >"$kdeglobals"
    tmp="$(mktemp "$kdeglobals.XXXXXX")" || return 1

    {
        # Everything the user already has, minus the colour groups, with
        # ColorScheme pointing at the active scheme.
        awk -v name="$name" '
            function is_colour(g) { return g ~ /^\[(Colors:|ColorEffects:)/ || g == "[WM]" }
            # Blank lines are held back until the next kept line, so dropped
            # groups leave no gaps and reruns produce identical output.
            function emit(line) {
                if (line == "") { pending = printed; return }
                if (pending) print ""
                pending = 0
                print line; printed = 1
            }
            /^\[/ {
                group = $0
                if (is_colour(group)) next
                emit(group)
                if (group == "[General]") { emit("ColorScheme=" name); seen_general = 1 }
                next
            }
            is_colour(group) { next }
            group == "[General]" && /^ColorScheme=/ { next }
            { emit($0) }
            END {
                if (!seen_general) {
                    if (printed) print ""
                    print "[General]"
                    print "ColorScheme=" name
                }
            }
        ' "$kdeglobals"
        printf '\n'
        # The scheme itself, inline.
        awk '
            function is_colour(g) { return g ~ /^\[(Colors:|ColorEffects:)/ || g == "[WM]" }
            /^\[/ { group = $0 }
            is_colour(group) { print }
        ' "$scheme_file"
    } >"$tmp"

    if cmp -s "$tmp" "$kdeglobals"; then
        rm -f "$tmp"
        return 0
    fi
    chmod --reference="$kdeglobals" "$tmp" 2>/dev/null || true
    mv "$tmp" "$kdeglobals"
    log "kdeglobals now carries the '$name' colours inline"
}

if ! command -v flatpak >/dev/null 2>&1; then
    exit 0
fi

rc=0
sync_overrides || rc=1
sync_kdeglobals || rc=1
exit "$rc"
