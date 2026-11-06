#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/display-control.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
runtime_dir="$tmp/runtime"
calls="$tmp/calls"
: > "$calls"
closed=true
lid_closed() { [[ "$closed" == true ]]; }
monitors_json() { printf '%s\n' "$fixture"; }
hyprctl() { printf '%s\n' "$*" >> "$calls"; }
internal='{"name":"eDP-1","width":1920,"height":1200,"refreshRate":60,"x":0,"y":0,"scale":1,"disabled":false}'
external='{"name":"DP-1","disabled":false}'
fixture="[$internal]"
reconcile_lid
[[ ! -s "$calls" ]] # Never disable the only screen.
fixture="[$internal,$external]"
reconcile_lid
[[ -s "$runtime_dir/lid-eDP-1" ]]
grep -q 'disabled = true' "$calls"
original=$(<"$runtime_dir/lid-eDP-1")
fixture="[$(jq '.disabled = true' <<< "$internal"),$external]"
reconcile_lid
[[ $(<"$runtime_dir/lid-eDP-1") == "$original" ]]
[[ $(wc -l < "$calls") == 1 ]] # Idempotent while closed.
closed=false
reconcile_lid
[[ ! -e "$runtime_dir/lid-eDP-1" ]]
grep -q '1920x1200@60' "$calls"
closed=true
fixture="[$internal,$external]"
reconcile_lid
fixture="[$(jq '.disabled = true' <<< "$internal")]"
reconcile_lid
[[ ! -e "$runtime_dir/lid-eDP-1" ]] # Unplug while closed restores the panel.
: > "$calls"
fixture="[$internal,$(jq '.disabled = true' <<< "$external")]"
reconcile_lid
[[ ! -s "$calls" ]] # A disabled external display is not a fallback.
printf 'Lid policy tests passed\n'
