#!/usr/bin/env bash
# Play one random sound from a named tier.
# Usage: IdleAlert.sh <tier>   e.g. warn, gentle, nag, dumbass
#
# Tier pools are bash arrays named SOUNDS_<tier> holding filenames relative
# to $SOUND_DIR. Built-in defaults below; override in ~/.config/hypr/idle-alert.conf.

set -u

SOUND_DIR="${IDLE_ALERT_SOUND_DIR:-$HOME/Music/notifications}"
CONF_FILE="${IDLE_ALERT_CONF:-$HOME/.config/hypr/idle-alert.conf}"

SOUNDS_warn=(
    "Excuse Me Sir.ogg"
    "Psst.ogg"
    "Calendar Event.ogg"
    "Sifi notification blip.ogg"
    "Kim Possible Beep.ogg"
    "Star Trek computer.ogg"
)

SOUNDS_gentle=(
    "Bleep.ogg"
    "Sifi notification blip.ogg"
    "Kim Possible Beep.ogg"
    "Psst.ogg"
    "Calendar Event.ogg"
    "Cha-Ching.ogg"
    "Star Trek computer.ogg"
    "mainframe02.ogg"
    "mainframe04.ogg"
    "mainframe12.ogg"
    "Galaga.ogg"
    "Cyberpunk.ogg"
    "Bottle Cap.ogg"
)

SOUNDS_nag=(
    "Grr Argh.ogg"
    "Oh no.ogg"
    "Mouthbreather.ogg"
    "Mouthbreather (1).ogg"
    "Computer Mumbling.ogg"
    "Weee.ogg"
    "Dethbleep.ogg"
    "Wolf.ogg"
    "Excuse Me Sir.ogg"
    "Psycho short.ogg"
    "Spooky Chime.ogg"
)

SOUNDS_dumbass=(
    "Error Spam.ogg"
    "Spam 1.ogg"
    "Spam.ogg"
    "Angerfist.ogg"
    "Vampire Call Sms.ogg"
    "Witch Cackle.ogg"
    "Evil Laugh.ogg"
    "Haunted Mansion Laugh.ogg"
    "Predator.ogg"
    "Oh no oh no.ogg"
    "It was at this moment .ogg"
    "Belial.ogg"
    "Vecna Clock.ogg"
)

# User overrides (sourced if present; safe no-op otherwise).
# shellcheck disable=SC1090
[[ -r "$CONF_FILE" ]] && source "$CONF_FILE"

if [[ $# -lt 1 ]]; then
    echo "usage: ${0##*/} <tier>" >&2
    exit 2
fi

tier="$1"
arr_name="SOUNDS_${tier}"

if ! declare -p "$arr_name" >/dev/null 2>&1; then
    echo "IdleAlert: unknown tier '$tier' (no array $arr_name)" >&2
    exit 1
fi

declare -n pool="$arr_name"

if (( ${#pool[@]} == 0 )); then
    echo "IdleAlert: tier '$tier' has no sounds" >&2
    exit 1
fi

idx=$(( RANDOM % ${#pool[@]} ))
sound="$SOUND_DIR/${pool[$idx]}"

if [[ ! -r "$sound" ]]; then
    echo "IdleAlert: missing sound file '$sound'" >&2
    exit 1
fi

exec pw-play "$sound"
