#!/usr/bin/env bash
# Power menu — pick a session/power action via wofi.
# Order matters: the first entry is what you get if you hit Enter by accident,
# so the safest action goes first and the destructive ones go last.

set -euo pipefail

CHOICES="\
Lock
Suspend
Hibernate
Logout
Reboot
Shutdown"

SELECTION="$(printf '%s' "$CHOICES" | wofi --show dmenu --prompt "power " --insensitive)"

LOCK='swaylock -f -C ~/.config/swaylock/config'

case "$SELECTION" in
  Lock) eval "$LOCK" ;;
  Suspend)
    eval "$LOCK" &
    sleep 0.3
    systemctl suspend
    ;;
  Hibernate)
    eval "$LOCK" &
    sleep 0.3
    systemctl hibernate
    ;;
  Logout) swaymsg exit ;;
  Reboot) systemctl reboot ;;
  Shutdown) systemctl poweroff ;;
esac
