#!/usr/bin/env bash
# Install the Ghostty terminal emulator.
#
# Ghostty is not in Fedora's default repos, so we enable the well-maintained
# scottames/ghostty COPR and install the native RPM from there. We wrap the
# COPR + dnf calls (rather than expect ghostty in system-packages.txt) because
# it lives in a third-party repo that has to be enabled first.
# Idempotent: safe to re-run.
set -euo pipefail

echo "[*] Enabling scottames/ghostty COPR..."
sudo dnf copr enable -y scottames/ghostty

echo "[*] Installing ghostty..."
sudo dnf install -y ghostty

echo ""
echo "[*] Ghostty installed. Sway's Mod+Return binding launches it."
echo ""
