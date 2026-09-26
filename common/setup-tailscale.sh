#!/usr/bin/env bash
# Install Tailscale and enable the tailscaled daemon.
#
# Defers to Tailscale's official installer, which adds the right repo and
# installs the package for the host distro. We wrap it (rather than hard-code
# the Fedora repo URL + dnf syntax) so upstream owns the part that changes.
# Idempotent: safe to re-run.
set -euo pipefail

echo "[*] Running Tailscale's official installer..."
curl -fsSL https://tailscale.com/install.sh | sh

# The installer enables tailscaled, but assert it anyway so this stays correct
# even if that ever changes. The node still needs 'tailscale up' to join your
# tailnet (interactive — opens a browser), so we don't run that here.
echo "[*] Ensuring tailscaled is enabled..."
sudo systemctl enable --now tailscaled

echo ""
echo "[*] Tailscale installed and tailscaled running."
echo ""
echo "    Authenticate this node (one-time, opens a browser):"
echo "      sudo tailscale up"
echo ""
echo "    Useful commands:"
echo "      tailscale status        — peers and connection state"
echo "      tailscale ip -4         — this node's tailnet IP"
echo "      sudo tailscale down     — disconnect from the tailnet"
echo ""
