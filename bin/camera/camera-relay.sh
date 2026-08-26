#!/usr/bin/env bash
# Relay the libcamera camera (Intel IPU7 / OV08X40) into a v4l2loopback node.
#
# Zoom, Chrome and Electron apps speak V4L2 and nothing else — they cannot use
# libcamera or the PipeWire camera portal — so a working libcamera device is
# invisible to them. This pushes frames into the loopback node so they see an
# ordinary /dev/videoN. Zoom lists it as "Virtual Camera".
#
# This wraps v4l2-relayd rather than running a gst-launch pipeline directly:
# relayd watches the loopback and only starts the camera pipeline while some
# app is actually reading from it, and tears it down when the last reader
# leaves. Idle cost is zero, so the service (modules/services.nix) is safe to
# leave enabled — no more remembering to start it before a call.
#
# Ubuntu ships v4l2-relayd as a system service, but /etc/v4l2-relayd.d/ is
# empty on IPU7 machines so it never starts, and configuring it means root,
# sudo round-trips and a hardening sandbox between us and every future tweak.
# A user service does the same job with the whole stack in the session, and
# keeps the config in the dotfiles. ubuntu/setup-camera.sh disables the system
# units so the two relayds never fight over the loopback.
#
# Usage:  camera-relay.sh                # native 1928x1088, saturation 1.3
#         W=1280 H=720 camera-relay.sh   # scaled output
#         SAT=1.5 camera-relay.sh        # punchier colour (1.0 off .. 2.0 max)
set -euo pipefail

W="${W:-1928}"
H="${H:-1088}"
SAT="${SAT:-1.3}"

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

echo "Relaying libcamera -> $DEV at ${W}x${H}, saturation ${SAT}"

# The caps filter directly on libcamerasrc is pinned to 3840x2160 — the
# ISP's output for the sensor's full 3856x2176 mode (the debayer trims the
# borders) — and both halves of that matter. Asking libcamera for a size it
# does not natively produce crashes the software ISP outright:
#
#   /usr/include/c++/15/array:210: Assertion '__n < this->size()' failed.
#
# (libcamera 0.7.0, simple pipeline; reproduced at 640x480, 720p and 1080p.)
# And of the two native modes, the binned 1928x1088 one debayers into a
# purple-tinted grid mess — some bayer-phase/stride disagreement between that
# readout and the ISP. The full mode is the only one that renders correctly,
# so W/H are videoscale's job, downstream of both bugs. Debayering runs on
# the GPU (Mesa/EGL), which is why 8MP here no longer costs 80% of a core.
#
# saturation only exists as a control because /usr/share/libcamera/ipa/simple/
# ov08x40.yaml (installed by ubuntu/setup-camera.sh) enables the Ccm algorithm.
# Without the tuning file the knob silently vanishes and the picture goes back
# to near-greyscale.
#
# sync=false on the sink: relayd forwards buffers with the camera pipeline's
# timestamps into a pipeline with its own clock. A syncing sink judges nearly
# every frame late and drops it — the camera "works" at 3fps. Unsynced, the
# loopback takes frames as they arrive at the sensor's ~28fps.
exec /usr/bin/v4l2-relayd \
  -i "libcamerasrc saturation=${SAT} ! video/x-raw,width=3840,height=2160 ! videoscale ! videoconvert" \
  -o "appsrc name=appsrc caps=video/x-raw,format=YUY2,width=${W},height=${H},framerate=30/1 ! videoconvert ! v4l2sink name=v4l2sink sync=false device=${DEV}"
