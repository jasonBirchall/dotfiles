#!/bin/sh
# Launch waybar, showing the battery module only on machines that have a
# battery. The committed config includes "battery"; on a desktop (no BAT*)
# we strip it out of modules-right at runtime so the module never appears.
set -eu

config="$HOME/.config/waybar/config"
style="$HOME/.config/waybar/style.css"

pkill waybar 2>/dev/null || true

if ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
  exec waybar -c "$config" -s "$style"
fi

# No battery present: drop the module and its definition into a runtime config.
runtime="${XDG_RUNTIME_DIR:-/tmp}/waybar-config.json"
jq 'del(.battery) | ."modules-right" |= map(select(. != "battery"))' \
  "$config" >"$runtime"
exec waybar -c "$runtime" -s "$style"
