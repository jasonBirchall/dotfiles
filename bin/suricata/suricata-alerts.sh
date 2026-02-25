#!/usr/bin/env bash
set -euo pipefail

# Quick Suricata alert summary
# Usage: suricata-alerts [hours]
#   Default: last 24 hours

EVE_LOG="/var/log/suricata/eve.json"
HOURS="${1:-24}"
SINCE=$(date -d "${HOURS} hours ago" --iso-8601=seconds 2>/dev/null || date -v-"${HOURS}"H +%Y-%m-%dT%H:%M:%S)

if [ ! -f "${EVE_LOG}" ]; then
  echo "No eve.json found. Is Suricata running?"
  echo "  Check: systemctl status suricata"
  exit 1
fi

ALERT_COUNT=$(jq -r "select(.event_type==\"alert\") | select(.timestamp >= \"${SINCE}\") | .alert.signature" "${EVE_LOG}" 2>/dev/null | wc -l)

echo "Suricata alerts — last ${HOURS}h (since ${SINCE})"
echo "Total alerts: ${ALERT_COUNT}"
echo ""

if [ "${ALERT_COUNT}" -gt 0 ]; then
  echo "By severity:"
  jq -r "select(.event_type==\"alert\") | select(.timestamp >= \"${SINCE}\") | \"\(.alert.severity) \(.alert.signature)\"" "${EVE_LOG}" 2>/dev/null |
    sort | uniq -c | sort -rn | head -20

  echo ""
  echo "Top source IPs:"
  jq -r "select(.event_type==\"alert\") | select(.timestamp >= \"${SINCE}\") | .src_ip" "${EVE_LOG}" 2>/dev/null |
    sort | uniq -c | sort -rn | head -10

  echo ""
  echo "Top destination IPs:"
  jq -r "select(.event_type==\"alert\") | select(.timestamp >= \"${SINCE}\") | .dest_ip" "${EVE_LOG}" 2>/dev/null |
    sort | uniq -c | sort -rn | head -10

  echo ""
  echo "For full details:"
  echo "  jq 'select(.event_type==\"alert\")' ${EVE_LOG} | less"
else
  echo "No alerts. All clear."
fi
