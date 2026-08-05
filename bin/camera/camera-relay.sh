#!/usr/bin/env bash
# Relay the libcamera camera (Intel IPU7 / OV08X40) into a v4l2loopback node.
#
# Zoom, Chrome and Electron apps speak V4L2 and nothing else — they cannot use
# libcamera or the PipeWire camera portal — so a working libcamera device is
# invisible to them. This pushes frames into the loopback node so they see an
# ordinary /dev/videoN. Zoom lists it as "Virtual Camera".
#
# Driven by the camera-relay user service (modules/services.nix), which is
# deliberately not enabled at boot: the software ISP costs ~80% of one core
# for as long as it runs, which is not something to leave on a laptop. Start
# it before a call, stop it after.
#
# Usage:  camera-relay.sh              # 720p
#         W=1920 H=1080 camera-relay.sh
set -euo pipefail

W="${W:-1280}"
H="${H:-720}"

# Find the loopback by card label rather than by number. v4l2loopback is not
# pinned to a fixed video_nr (/etc/modprobe.d/v4l2-relayd.conf sets only
# exclusive_caps and card_label), and it competes for numbers with the 30-odd
# IPU7 ISYS nodes, so which one it lands on varies between boots.
DEV=""
for d in /sys/class/video4linux/video*; do
  if [ "$(cat "$d/name" 2>/dev/null)" = "Virtual Camera" ]; then
    DEV="/dev/$(basename "$d")"
    break
  fi
done

if [ -z "$DEV" ]; then
  echo "ERROR: no v4l2loopback 'Virtual Camera' node found." >&2
  echo "       Check the module is loaded: lsmod | grep v4l2loopback" >&2
  echo "       It comes from the v4l2loopback-dkms package." >&2
  exit 1
fi

echo "Relaying libcamera -> $DEV at ${W}x${H}"

# Do NOT put width/height caps on libcamerasrc itself, however tempting it is
# to let the ISP do the scaling. Asking libcamera for a non-native size crashes
# the software ISP outright:
#
#   /usr/include/c++/15/array:210: Assertion '__n < this->size()' failed.
#
# libcamera 0.7.0 ships no sensor helper and no tuning file for ov08x40, so it
# falls back to uncalibrated.yaml and indexes past the end of a 64-entry array.
# Taking the native mode and scaling in GStreamer afterwards avoids it. The
# same missing tuning data is why the picture is flatter than it should be.
exec gst-launch-1.0 \
  libcamerasrc \
  ! videoconvert \
  ! videoscale \
  ! video/x-raw,format=YUY2,width="$W",height="$H" \
  ! v4l2sink device="$DEV"
