#!/usr/bin/env bash
# Drive the Dell D6000 dock's display outputs. Ubuntu-only: the dock lives on
# the work laptop, and the Fedora hosts have no DisplayLink hardware.
#
# The D6000 is not a Thunderbolt/USB-C-alt-mode dock. Its video outputs sit
# behind a DisplayLink DL-6950 chip, which the kernel drives as a USB device
# (17e9:6006), not as a GPU. Plugged in on a stock install, the dock's network,
# audio and USB ports all work and the monitors stay black. Two pieces are
# needed for video, and only the second is proprietary:
#
#   1. evdi — the "Extensible Virtual Display Interface" kernel module. Open
#      source and packaged by Ubuntu as evdi-dkms, which is patched to build
#      against the release's kernel. Synaptics ships its own evdi too, but its
#      supported-kernel ceiling trails Ubuntu's kernel (6.17 vs 7.0 as of the
#      6.3 driver), so Ubuntu's package is the one that actually builds here.
#   2. DisplayLinkManager — Synaptics' user-space daemon that talks USB to the
#      chip and feeds frames into evdi. Only available from Synaptics' signed
#      apt repository (or a .run installer that unpacks the same thing).
#
# The displaylink-driver package depends on "evdi | evdi-dkms", so installing
# Ubuntu's evdi-dkms first satisfies it without pulling Synaptics' evdi in.
# Once the repo is enabled, `make update` carries the driver forward through
# apt like everything else. If a future kernel jump breaks the DKMS build, the
# fix is a newer evdi-dkms, not a change here.
#
# Not in `bootstrap`: it builds a DKMS module and adds a third-party repo, and
# it is only useful on a host that meets this dock. Idempotent: safe to re-run.
set -euo pipefail

KEYRING_URL="https://www.synaptics.com/sites/default/files/Ubuntu/pool/stable/main/all/synaptics-repository-keyring.deb"
KEYRING_PKG="synaptics-repository-keyring"

if ! grep -qsi ubuntu /etc/os-release; then
  echo "    This script targets Ubuntu (apt + Ubuntu's evdi-dkms). Nothing to do." >&2
  exit 0
fi

if ! lsusb 2>/dev/null | grep -qi displaylink; then
  echo "    No DisplayLink device on USB right now. Installing anyway — plug the dock in afterwards." >&2
fi

if command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -q enabled; then
  echo "    Secure Boot is enabled: the unsigned evdi module will not load without MOK enrolment." >&2
  echo "    Enrol the DKMS key (sudo dkms generate_mok / mokutil --import) or disable Secure Boot, then re-run." >&2
  exit 1
fi

echo "[*] Installing Ubuntu's evdi kernel module (DKMS build for $(uname -r))..."
sudo apt-get install -y "linux-headers-$(uname -r)" dkms evdi-dkms libevdi1

if dpkg-query -W -f='${Status}' "$KEYRING_PKG" 2>/dev/null | grep -q "install ok installed"; then
  echo "[*] Synaptics apt repository already configured."
else
  echo "[*] Adding the Synaptics apt repository and signing key..."
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL --proto '=https' --tlsv1.2 -o "$tmp/$KEYRING_PKG.deb" "$KEYRING_URL"
  sudo apt-get install -y "$tmp/$KEYRING_PKG.deb"
fi

echo "[*] Installing displaylink-driver..."
sudo apt-get update -qq
sudo apt-get install -y displaylink-driver

echo "[*] Loading evdi and enabling the DisplayLink service..."
sudo modprobe evdi
sudo systemctl enable --now displaylink-driver.service

echo ""
echo "[*] DisplayLink installed."
echo ""
dkms status 2>/dev/null | grep evdi || echo "    (evdi not listed by dkms — check: sudo dkms status)"
systemctl is-active --quiet displaylink-driver.service && echo "    displaylink-driver.service: active" || echo "    displaylink-driver.service: NOT active — check: journalctl -u displaylink-driver"
echo ""
echo "    Unplug and replug the dock. If its monitors stay black, log out and"
echo "    back in so the session picks up the new evdi outputs (/sys/class/drm)."
echo ""
