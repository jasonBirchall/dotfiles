#!/usr/bin/env bash
# Show a searchable cheatsheet of sway keybindings via wofi.
# Reads the live sway config and formats every `bindsym` line, prefixing
# any binding that lives inside a named mode (e.g. "resize") with [<mode>].

set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/sway/config"

awk '
  BEGIN { mode = ""; in_mode = 0 }
  /^[[:space:]]*mode[[:space:]]+"/ {
    match($0, /"[^"]+"/)
    mode = substr($0, RSTART + 1, RLENGTH - 2)
    in_mode = 1
    next
  }
  in_mode && /^\}/ { in_mode = 0; mode = ""; next }
  /^[[:space:]]*bindsym/ {
    line = $0
    sub(/^[[:space:]]*bindsym[[:space:]]+/, "", line)
    idx = index(line, " ")
    key = substr(line, 1, idx - 1)
    rest = substr(line, idx + 1)
    if (mode != "")
      printf "[%s] %-22s  %s\n", mode, key, rest
    else
      printf "%-26s  %s\n", key, rest
  }
' "$CONFIG" | wofi --show dmenu --prompt "sway " --insensitive --width 900 --height 600 >/dev/null
