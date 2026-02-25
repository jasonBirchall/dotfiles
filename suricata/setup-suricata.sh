#!/usr/bin/env bash
set -euo pipefail

# Setup Suricata in passive IDS mode
# Designed to be run once after 'make dnf' installs suricata

IFACE="${1:-$(ip route show default | awk '/default/ {print $5}' | head -1)}"
LOG_DIR="/var/log/suricata"
RULES_DIR="/var/lib/suricata/rules"

echo "[*] Configuring Suricata for passive IDS on interface: ${IFACE}"

# Ensure log directory exists and is readable by the user
# Suricata defaults to 750 which blocks non-root access
sudo mkdir -p "${LOG_DIR}"
sudo chmod 755 "${LOG_DIR}"

# Download ET Open ruleset (FOSS, no subscription needed)
echo "[*] Updating ET Open rules..."
sudo suricata-update

# Set the interface in the default config
# The default suricata.yaml ships with the package — we patch it rather than
# maintaining a full copy, so we pick up upstream improvements on update
SURICATA_YAML="/etc/suricata/suricata.yaml"

if sudo test -f "${SURICATA_YAML}"; then
  # Set the default interface
  sudo sed -i "s/^  - interface: .*/  - interface: ${IFACE}/" "${SURICATA_YAML}"

  # Enable eve-log (JSON structured logging) if not already
  echo "[*] Verifying eve-log is enabled..."
  sudo grep -q "eve-log:" "${SURICATA_YAML}" && echo "    eve-log found in config"
else
  echo "[!] Suricata config not found at ${SURICATA_YAML}"
  echo "    Is suricata installed? Run 'make dnf' first."
  exit 1
fi

# Create a drop-in override for the systemd service to pin the interface
sudo mkdir -p /etc/systemd/system/suricata.service.d
sudo tee /etc/systemd/system/suricata.service.d/override.conf >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/suricata -c /etc/suricata/suricata.yaml --af-packet=${IFACE} --user suricata
EOF

sudo systemctl daemon-reload
sudo systemctl enable suricata
sudo systemctl restart suricata

# Add current user to suricata group for log access
if ! groups | grep -q suricata; then
  sudo usermod -aG suricata "$(whoami)"
  echo "[*] Added $(whoami) to suricata group (effective after next login)"
fi

echo ""
echo "[*] Suricata is running in passive IDS mode on ${IFACE}"
echo ""
echo "    Logs:"
echo "      ${LOG_DIR}/eve.json    — structured JSON events"
echo "      ${LOG_DIR}/fast.log    — one-line alert summaries"
echo ""
echo "    Useful commands:"
echo "      journalctl -u suricata -f          — service logs"
echo "      jq 'select(.event_type==\"alert\")' ${LOG_DIR}/eve.json  — alerts only"
echo "      suricata-update && sudo systemctl restart suricata      — update rules"
echo ""
echo "    Add a cron job for weekly rule updates:"
echo "      sudo crontab -e"
echo "      0 3 * * 0 suricata-update && systemctl restart suricata"
