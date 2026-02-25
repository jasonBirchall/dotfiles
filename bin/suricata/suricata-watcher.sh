#!/usr/bin/env bash
set -euo pipefail

# Real-time watcher for high-severity Suricata alerts
# Tails eve.json and sends desktop notifications for ET MALWARE / ET EXPLOIT
# Designed to run as a long-lived systemd user service
EVE_LOG="/var/log/suricata/eve.json"
COOLDOWN_DIR="/tmp/suricata-notify-cooldown"

# Minimum seconds between notifications for the same signature
COOLDOWN_SECS=300

mkdir -p "${COOLDOWN_DIR}"

export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

notify_alert() {
  local sig="$1"
  local sid="$2"
  local src="$3"
  local dst="$4"
  local severity="$5"

  # Cooldown: skip if we notified for this SID recently
  local cooldown_file="${COOLDOWN_DIR}/${sid}"
  if [ -f "${cooldown_file}" ]; then
    local last_notify
    last_notify=$(cat "${cooldown_file}")
    local now
    now=$(date +%s)
    if ((now - last_notify < COOLDOWN_SECS)); then
      return 0
    fi
  fi

  date +%s >"${cooldown_file}"

  local urgency="critical"

  notify-send \
    --urgency="${urgency}" \
    --app-name="Suricata IDS" \
    "🚨 ${sig}" \
    "SID: ${sid}\nSource: ${src}\nDestination: ${dst}\nSeverity: ${severity}\n\nRun 'alerts' for full details"
}

# Wait for the log file to exist
while [ ! -f "${EVE_LOG}" ]; do
  sleep 10
done

# Tail the log, filtering for alerts matching ET MALWARE or ET EXPLOIT
tail -n 0 -F "${EVE_LOG}" |
  jq --unbuffered -r '
    select(.event_type == "alert")
    | select(.alert.signature | test("ET (MALWARE|EXPLOIT|TROJAN)"; "i"))
    | [.alert.signature, (.alert.signature_id | tostring), .src_ip, .dest_ip, (.alert.severity | tostring)]
    | @tsv
  ' 2>/dev/null |
  while IFS=$'\t' read -r sig sid src dst severity; do
    notify_alert "${sig}" "${sid}" "${src}" "${dst}" "${severity}"
  done
