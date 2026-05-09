#!/usr/bin/env bash
set -euo pipefail

# Install the proprietary NVIDIA driver and configure suspend/resume.
# Designed for Turing+ cards on Wayland (sway). Idempotent — safe to re-run.
#
# What this does:
#   1. Enables RPM Fusion (free + nonfree) — akmod-nvidia lives there
#   2. Installs akmod-nvidia (declared in fedora/system-packages.txt)
#   3. Drops a modprobe.d config to preserve VRAM across suspend
#   4. Enables the nvidia-{suspend,resume,hibernate} systemd services
#
# After running, REBOOT. The akmod kernel module takes ~5 minutes to build on
# first boot — `modinfo nvidia` will work once it has finished.

FEDORA_VER="$(rpm -E %fedora)"
RPMFUSION_FREE_URL="https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm"
RPMFUSION_NONFREE_URL="https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"

echo "[*] Enabling RPM Fusion (free + nonfree) on Fedora ${FEDORA_VER}..."
if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
  sudo dnf install -y "${RPMFUSION_FREE_URL}"
else
  echo "    rpmfusion-free-release already installed"
fi

if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
  sudo dnf install -y "${RPMFUSION_NONFREE_URL}"
else
  echo "    rpmfusion-nonfree-release already installed"
fi

echo "[*] Installing akmod-nvidia..."
sudo dnf install -y akmod-nvidia

# Preserve video memory across suspend/resume. Without this, resume from
# suspend on Wayland with NVIDIA is unreliable on Turing+ cards.
NVIDIA_PM_CONF="/etc/modprobe.d/nvidia-power-management.conf"
echo "[*] Writing ${NVIDIA_PM_CONF}..."
sudo tee "${NVIDIA_PM_CONF}" >/dev/null <<'EOF'
# Managed by dotfiles/fedora/setup-nvidia.sh
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
# Disable GSP firmware on Turing — newer drivers default to GSP-offload mode
# which has known suspend/resume bugs (Xid 119 GSP RPC timeouts). Turing
# supports the legacy in-kernel path; Ampere+ does not, so do not copy this
# line onto Ampere/Ada hardware.
options nvidia NVreg_EnableGpuFirmware=0
EOF

echo "[*] Enabling nvidia suspend/resume/hibernate services..."
sudo systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service

# Required for Wayland and for suspend/resume to restore the display correctly.
# Without nvidia-drm.modeset=1 the nvidia_drm module only loads as a passive DRM
# driver and can't preserve display state across suspend; resume comes back to
# a black screen. fbdev=1 is recommended on driver >=525 — gives the kernel an
# fbdev backed by nvidia, which also helps VT switching.
echo "[*] Adding nvidia-drm kernel args via grubby..."
sudo grubby --update-kernel=ALL --args="nvidia-drm.modeset=1 nvidia-drm.fbdev=1"

# Compile and load the local SELinux policy module that allows
# systemd-sleep to write VRAM-preservation files to /var/tmp during suspend.
# Re-installing an already-loaded module just updates it (idempotent).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELINUX_TE="${SCRIPT_DIR}/nvidia-suspend.te"
SELINUX_BUILD="$(mktemp -d)"
trap 'rm -rf "${SELINUX_BUILD}"' EXIT

echo "[*] Building & loading nvidia-suspend SELinux policy module..."
cp "${SELINUX_TE}" "${SELINUX_BUILD}/"
(
  cd "${SELINUX_BUILD}"
  checkmodule -M -m -o nvidia-suspend.mod nvidia-suspend.te
  semodule_package -o nvidia-suspend.pp -m nvidia-suspend.mod
)
sudo semodule -i "${SELINUX_BUILD}/nvidia-suspend.pp"

# Sway refuses to start on proprietary NVIDIA without --unsupported-gpu (it's
# wlroots's deliberate policy). Override the session entry so the greeter
# launches sway with the flag and the env vars NVIDIA needs on Wayland.
# /usr/local/share/wayland-sessions/ is unmanaged by any package, so this
# survives sway upgrades.
SWAY_SESSION="/usr/local/share/wayland-sessions/sway.desktop"
echo "[*] Writing ${SWAY_SESSION}..."
sudo mkdir -p "$(dirname "${SWAY_SESSION}")"
sudo tee "${SWAY_SESSION}" >/dev/null <<'EOF'
[Desktop Entry]
Name=Sway (NVIDIA)
Comment=An i3-compatible Wayland compositor (proprietary NVIDIA driver)
Exec=env WLR_NO_HARDWARE_CURSORS=1 __GLX_VENDOR_LIBRARY_NAME=nvidia GBM_BACKEND=nvidia-drm LIBVA_DRIVER_NAME=nvidia sway --unsupported-gpu
Type=Application
DesktopNames=sway;wlroots
EOF

cat <<'EOF'

[*] NVIDIA setup complete.

    Next steps:
      1. Reboot.
      2. After reboot, wait ~5 minutes for the akmod to build on first boot.
         Verify with:   modinfo -F version nvidia
      3. Confirm the driver is in use: lspci -k | grep -A2 -i 'vga\|3d'
         You should see "Kernel driver in use: nvidia".
      4. Test suspend with:  systemctl suspend
         Or use the sway binding ($mod+Shift+s).

    If suspend still hangs on resume, capture logs from the previous boot:
      journalctl -b -1 -k | grep -iE 'nvidia|suspend|resume'
EOF
