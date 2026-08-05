#!/usr/bin/env bash
# Make the internal camera work on Intel IPU7 (MIPI) laptops — Dell Pro 13
# Premium PA13250 and relatives. Ubuntu-only: Fedora hosts in this repo have
# UVC webcams, which need none of this.
#
# There is no USB webcam on these machines. The camera is a MIPI sensor
# (OV08X40) behind Intel's IPU7 ISP, and four separate things have to be true
# before an application sees a picture. Only the third is missing from a stock
# Ubuntu install, but the symptom of missing it looks identical to the other
# three, which is what makes this worth writing down:
#
#   1. Kernel drivers. Present since 6.17 (intel_ipu7_isys, still in staging).
#   2. libcamera + the PipeWire plugin. Packaged — see ubuntu/system-packages.txt.
#      Plain V4L2 cannot drive this hardware: /dev/video0..31 are raw ISYS CSI
#      receiver endpoints with no debayer, no AE and no AWB. Apps enumerate 30-odd
#      "cameras" and every one of them is black.
#   3. intel_cvs. THE MISSING PIECE, and what this script installs.
#   4. A V4L2 bridge for apps that cannot speak libcamera. See the relay service
#      in modules/services.nix.
#
# On (3): the Vision Sensing Controller (ACPI INTC10DE) owns the sensor at boot
# and has to hand it to the host. No Ubuntu kernel — generic or OEM — ships a
# driver for it; it exists only out-of-tree in intel/vision-drivers. Without it
# the sensor's ACPI _DEP chain never resolves, so ov08x40 never probes, no
# v4l2 subdev is created, and `cam -l` reports zero cameras. The tell is that
# /sys/bus/acpi/devices/OVTI08F4:00 reports status 15 (present and functional)
# yet has no physical_node. Success looks like this in dmesg:
#
#   Intel CVS driver i2c-INTC10DE:00: cvs_common_probe:Transfer of ownership success
#
# Do not be misled by "int3472-discrete INT3472:00: GPIO type 0x02 unknown;
# the sensor may not work" at boot. It is unrelated to the RGB camera — 0x02 is
# the IR strobe LED for face auth, whose support is still unmerged upstream
# (https://lwn.net/Articles/1065085/). It is expected and harmless here.
#
# Idempotent: re-running removes the previous DKMS registration first, and
# refreshes the checkout rather than stacking onto it.
set -euo pipefail

SRC_DIR="${VISION_DRIVERS_SRC:-$HOME/Documents/workarea/vision-drivers}"
DKMS_NAME="vision-driver"
DKMS_VER="1.0.0"
DKMS_DEST="/usr/src/${DKMS_NAME}-${DKMS_VER}"

if [ ! -e /sys/bus/acpi/devices/INTC10DE:00 ] && [ ! -e /sys/bus/acpi/devices/INTC10E1:00 ]; then
  echo "    No Intel CVS device (INTC10DE/INTC10E1) on this host — nothing to do." >&2
  echo "    This script is only for IPU6/IPU7 MIPI camera laptops." >&2
  exit 0
fi

echo "[*] Installing build dependencies..."
sudo apt install -y build-essential dkms git

if [ -d "$SRC_DIR/.git" ]; then
  echo "[*] Fetching upstream into existing checkout at $SRC_DIR"
  git -C "$SRC_DIR" fetch --quiet origin
  git -C "$SRC_DIR" reset --quiet --hard origin/HEAD
else
  echo "[*] Cloning intel/vision-drivers into $SRC_DIR"
  git clone --quiet https://github.com/intel/vision-drivers.git "$SRC_DIR"
fi

echo "[*] Registering with DKMS as ${DKMS_NAME}/${DKMS_VER}"
sudo dkms remove -m "$DKMS_NAME" -v "$DKMS_VER" --all 2>/dev/null || true
sudo rm -rf "$DKMS_DEST"
sudo cp -r "$SRC_DIR" "$DKMS_DEST"
sudo rm -rf "$DKMS_DEST/.git"

# PATH is forced to the system one for the DKMS build. Nix puts its own gcc and
# make ahead of /usr/bin in this user's PATH (modules/packages.nix), and
# building an out-of-tree module against Ubuntu's kernel headers with a
# different toolchain than the kernel was built with is a long way to a
# confusing failure. Ubuntu's gcc is already the right version by construction.
echo "[*] Building (Ubuntu toolchain, not Nix's)"
sudo env PATH=/usr/bin:/bin:/usr/sbin:/sbin dkms build -m "$DKMS_NAME" -v "$DKMS_VER"
sudo env PATH=/usr/bin:/bin:/usr/sbin:/sbin dkms install -m "$DKMS_NAME" -v "$DKMS_VER"

# Probe order is not incidental. intel_ipu7 binding the sensor before the USBIO
# i2c bridge, the CVS controller and the INT3472 power/GPIO driver are up leaves
# the _DEP chain unsatisfied, and you get the stock no-camera failure with the
# driver correctly installed — the most confusing possible outcome.
echo "[*] Writing /etc/modprobe.d/intel-cvs-camera.conf"
sudo tee /etc/modprobe.d/intel-cvs-camera.conf >/dev/null <<'EOF'
# Managed by dotfiles (ubuntu/setup-camera.sh). See that script for why.
softdep intel_ipu7 pre: usbio gpio_usbio i2c_usbio intel_cvs intel_skl_int3472_discrete
EOF

sudo update-initramfs -u

echo ""
echo "[*] intel_cvs installed:"
sudo dkms status -m "$DKMS_NAME"
echo ""
echo "    Reboot, then check the sensor came up:"
echo "      cam -l          # expect exactly 1 camera, not 0 and not 30"
echo ""
echo "    For Zoom/Chrome, start the relay (they cannot speak libcamera):"
echo "      systemctl --user start camera-relay"
echo ""
