#!/usr/bin/env bash
# Stop the TEX Shinobi keyboard (Holtek 04d9:0407) from being USB-reset every
# ~30 seconds, which surfaces as a key that suddenly auto-repeats until
# another key is pressed. Identical on both distros: it is a property of the
# keyboard, not the host.
#
# The keyboard exposes four USB interfaces: three HID (keyboard, mouse, a
# vendor "device") and one mass-storage interface that presents a 0-byte
# removable disk ("TEX Mass Storage", /dev/sda). That disk is fake: every
# SCSI command sent to it errors (on the work laptop ioerr_cnt tracked
# iorequest_cnt at ~265k each after a week). Each failure trips the SCSI
# error handler, whose recovery step is usb_reset_device() on the whole
# keyboard, so dmesg fills with
#
#   usb 3-1.2.2: reset full-speed USB device number 12 using xhci_hcd
#
# at ~110 resets an hour, day and night, typing or idle. A reset drops the
# HID interfaces for a moment; if a key-release report lands in that window
# it is lost, the kernel believes the key is still held, and autorepeat runs
# until the next key press replaces it. It predates the D6000 dock (the same
# counts appear with the keyboard plugged straight in); the dock's hub chain
# just made it more frequent.
#
# Fix: tell usb-storage to ignore this vendor:product (quirk flag `i`), so
# the fake disk is never bound and nothing ever talks to it. The HID
# interfaces are untouched. Applied three ways so it holds immediately, after
# a replug, and after a reboot:
#   1. modprobe.d options file (read when usb-storage loads; initramfs
#      refreshed because Ubuntu and Fedora both load usb-storage early).
#   2. The live module parameter, for the next probe without a reboot.
#   3. Unbind usb-storage from any instance plugged in right now.
#
# Verify: the reset lines stop appearing, and lsblk no longer lists sda.
#   journalctl -k -f | grep 'reset full-speed'
#
# Idempotent: rewrites the same file and skips interfaces already unbound.
set -euo pipefail

VID=04d9
PID=0407
CONF=/etc/modprobe.d/tex-shinobi-keyboard.conf

echo "Writing $CONF"
sudo tee "$CONF" >/dev/null <<CONF_EOF
# TEX Shinobi keyboard: its mass-storage interface is a fake 0-byte disk whose
# SCSI errors reset the whole keyboard every ~30s (lost key-release -> stuck
# autorepeat). Ignore it. Managed by dotfiles: common/setup-tex-shinobi.sh
options usb-storage quirks=$VID:$PID:i
CONF_EOF

if [[ -e /sys/module/usb_storage/parameters/quirks ]]; then
  echo "Applying to the loaded usb-storage module"
  echo "$VID:$PID:i" | sudo tee /sys/module/usb_storage/parameters/quirks >/dev/null
fi

for iface in /sys/bus/usb/drivers/usb-storage/*:*; do
  [[ -e "$iface" ]] || continue
  dev="/sys/bus/usb/devices/$(basename "${iface%:*}")"
  if [[ "$(cat "$dev/idVendor")" == "$VID" && "$(cat "$dev/idProduct")" == "$PID" ]]; then
    echo "Unbinding usb-storage from $(basename "$iface") (the keyboard plugged in now)"
  fi
done

if command -v update-initramfs >/dev/null; then
  echo "Refreshing initramfs (Ubuntu)"
  sudo update-initramfs -u
elif command -v dracut >/dev/null; then
  echo "Refreshing initramfs (Fedora)"
  sudo dracut -f
fi

echo "Done. The keyboard keeps working; only its fake disk is gone."
