#!/usr/bin/env bash
# NetworkBandwidth.sh --up|--down
# Emits current bandwidth for the default-route interface, in Mb/s with one decimal.
# Stores last-seen counter + timestamp per direction in /tmp so successive calls
# can compute the delta. Always reports in megabits (never kilo/bytes), padded so
# the waybar slot has a stable width.

set -u

direction="${1:---down}"
case "$direction" in
  --up|--down) ;;
  *) printf '?\n'; exit 0 ;;
esac

state_file="/tmp/waybar_net_${direction#--}_$(id -u)"

iface=$(ip -j route show default 2>/dev/null | jq -r '.[0].dev // empty' 2>/dev/null)
if [ -z "$iface" ]; then
  arrow="↓"; [ "$direction" = "--up" ] && arrow="↑"
  printf '%s   --\n' "$arrow"
  exit 0
fi

read -r rx tx < <(awk -v key="${iface}:" '$1 == key { print $2, $10 }' /proc/net/dev)
if [ -z "${rx:-}" ]; then
  arrow="↓"; [ "$direction" = "--up" ] && arrow="↑"
  printf '%s   --\n' "$arrow"
  exit 0
fi

case "$direction" in
  --up)   counter=$tx; arrow="↑" ;;
  --down) counter=$rx; arrow="↓" ;;
esac

now_ns=$(date +%s%N)
rate_bps=0
if [ -f "$state_file" ]; then
  read -r prev_ns prev_counter < "$state_file" 2>/dev/null || { prev_ns=0; prev_counter=0; }
  if [ -n "${prev_ns:-}" ] && [ -n "${prev_counter:-}" ] && [ "$prev_ns" -gt 0 ]; then
    delta=$(( counter - prev_counter ))
    dt_ns=$(( now_ns - prev_ns ))
    if [ "$delta" -ge 0 ] && [ "$dt_ns" -gt 0 ]; then
      # bits per second = bytes_delta * 8 * 1e9 / dt_ns
      rate_bps=$(( delta * 8 * 1000000000 / dt_ns ))
    fi
  fi
fi
printf '%s %s\n' "$now_ns" "$counter" > "$state_file"

mbps=$(awk -v b="$rate_bps" 'BEGIN { printf "%.1f", b / 1000000 }')
printf '%s %5s Mb\n' "$arrow" "$mbps"
