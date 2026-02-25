#!/usr/bin/env bash
set -euo pipefail

# Hourly Suricata alert check with desktop notification
# Designed to run via systemd timer, notifies via mako

EVE_LOG="/var/log/suricata/eve.json"
SINCE=$(date -d "1 hour ago" --iso-8601=seconds)

if [ ! -f "${EVE_LOG}" ]; then
  exit 0
fi

# Count alerts in the last hour
ALERT_COUNT=$(jq -r "select(.event_type==\"alert\") | select(.timestamp >= \"${SINCE}\") | .alert.signature" "${EVE_LOG}" 2>/dev/null | wc -l)

if [ "${ALERT_COUNT}" -eq 0 ]; then
  exit 0
fi

# Get the highest severity (1 = highest in Suricata)
HIGHEST_SEV=$(jq -r "select(.event_type==\"alert\") | select(.timestamp >= \"${SINCE}\") | .alert.severity" "${EVE_LOG}" 2>/dev/null | sort -n | head -1)

# Top 3 signatures for the notification body
TOP_SIGS=$(jq -r "select(.event_type==\"alert\") | select(.timestamp >= \"${SINCE}\") | .alert.signature" "${EVE_LOG}" 2>/dev/null |
  sort | uniq -c | sort -rn | head -3 | awk '{$1=$1; print "• "$0}')

# Set urgency based on severity
URGENCY="normal"
if [ "${HIGHEST_SEV}" -le 1 ]; then
  URGENCY="critical"
fi

# Send notification via notify-send (picked up by mako)
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

notify-send \
  --urgency="${URGENCY}" \
  --app-name="Suricata IDS" \
  "⚠ ${ALERT_COUNT} network alert(s) in the last hour" \
  "${TOP_SIGS}\n\nRun 'alerts' for details"
