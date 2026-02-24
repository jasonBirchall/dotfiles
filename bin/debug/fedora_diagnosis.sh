#!/usr/bin/env bash
set -euo pipefail

# Post-crash diagnostic script for Sway + NVIDIA resume issues
# Run this after a reboot following a crash/freeze
OUTDIR="${HOME}/crash-reports"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_DIR="${OUTDIR}/${TIMESTAMP}"
REPORT="${REPORT_DIR}/summary.txt"

mkdir -p "${REPORT_DIR}"

log() {
  echo "[*] $1"
  echo "=== $1 ===" >>"${REPORT}"
}

separator() {
  echo "" >>"${REPORT}"
  echo "---" >>"${REPORT}"
  echo "" >>"${REPORT}"
}

echo "Post-crash diagnostic — $(date)"
echo "Report directory: ${REPORT_DIR}"
echo ""

# Header
cat >>"${REPORT}" <<EOF
Post-Crash Diagnostic Report
Generated: $(date)
Host: $(hostname)
Kernel: $(uname -r)
EOF
separator

# ── Previous boot errors ──
log "Previous boot errors (priority: err and above)"
journalctl -b -1 -p err --no-pager 2>/dev/null >>"${REPORT}" || echo "No previous boot found" >>"${REPORT}"
separator

# ── Final 200 lines of previous boot ──
log "Final 200 lines of previous boot"
journalctl -b -1 -o short-monotonic --no-pager 2>/dev/null | tail -200 >>"${REPORT}" || echo "No previous boot found" >>"${REPORT}"
separator

# ── NVIDIA / DRM / GPU messages ──
log "NVIDIA / DRM / GPU kernel messages (previous boot)"
journalctl -b -1 --no-pager 2>/dev/null | grep -iE "NVRM|nvidia|gpu|drm|render|nouveau" >>"${REPORT}" || echo "None found" >>"${REPORT}"
separator

# ── Kernel panics / oops ──
log "Kernel panics and oops (previous boot)"
journalctl -b -1 --no-pager 2>/dev/null | grep -iE "panic|oops|BUG:|RIP:|Call Trace" >>"${REPORT}" || echo "None found" >>"${REPORT}"
separator

# ── OOM killer ──
log "OOM killer activity (previous boot)"
journalctl -b -1 --no-pager 2>/dev/null | grep -iE "oom|out of memory|killed process" >>"${REPORT}" || echo "None found" >>"${REPORT}"
separator

# ── Swayidle / Swaylock ──
log "Swayidle and swaylock messages (previous boot)"
journalctl -b -1 --no-pager 2>/dev/null | grep -iE "swayidle|swaylock" >>"${REPORT}" || echo "None found" >>"${REPORT}"
separator

# ── Sway messages ──
log "Sway compositor messages (previous boot)"
journalctl -b -1 --no-pager 2>/dev/null | grep -iE "sway\b" >>"${REPORT}" || echo "None found" >>"${REPORT}"
separator

# ── Suspend / resume ──
log "Suspend and resume events (previous boot)"
journalctl -b -1 --no-pager 2>/dev/null | grep -iE "suspend|resume|sleep|PM:|hibernate" >>"${REPORT}" || echo "None found" >>"${REPORT}"
separator

# ── Current boot — early errors ──
log "Current boot errors (may show recovery issues)"
journalctl -b 0 -p err --no-pager 2>/dev/null | head -50 >>"${REPORT}"
separator

# ── System info ──
log "System information"
{
  echo "Kernel: $(uname -r)"
  echo "Sleep mode: $(cat /sys/power/mem_sleep 2>/dev/null || echo 'unknown')"
  echo ""

  echo "NVIDIA driver:"
  lspci -k 2>/dev/null | grep -A3 -i nvidia || echo "No NVIDIA device found"
  echo ""

  echo "NVIDIA module parameters:"
  if [ -d /sys/module/nvidia ]; then
    for param in /sys/module/nvidia/parameters/*; do
      echo "  $(basename "${param}") = $(cat "${param}" 2>/dev/null || echo 'unreadable')"
    done
  else
    echo "  nvidia module not loaded"
  fi
  echo ""

  echo "GPU power state:"
  for card in /sys/class/drm/card*/device/power_state; do
    [ -f "${card}" ] && echo "  ${card}: $(cat "${card}")"
  done
  echo ""

  echo "Swap usage:"
  swapon --show 2>/dev/null || echo "No swap"
  echo ""

  echo "Memory:"
  free -h
} >>"${REPORT}"
separator

# ── Save full previous boot journal ──
log "Saving full previous boot journal"
journalctl -b -1 --no-pager >"${REPORT_DIR}/full-journal-prev-boot.log" 2>/dev/null || echo "No previous boot journal available"

# ── Save current dmesg ──
dmesg >"${REPORT_DIR}/dmesg-current.log" 2>/dev/null || true

echo ""
echo "Done. Report saved to:"
echo "  ${REPORT_DIR}/summary.txt        — key findings"
echo "  ${REPORT_DIR}/full-journal-prev-boot.log — complete previous boot log"
echo "  ${REPORT_DIR}/dmesg-current.log  — current kernel ring buffer"
echo ""
echo "Quick check — run:"
echo "  less ${REPORT}"
