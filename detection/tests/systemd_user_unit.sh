#!/usr/bin/env bash
# ATT&CK T1543.002 — systemd service persistence.
# ART atomic d9e4f24f-aa67-4c6e-bcbf-85622b697a7c ("Create Systemd Service")
# writes to /etc/systemd/system (root, system-wide). This machine's watch is
# on the *user* unit dir, so this test overrides the path to
# ~/.config/systemd/user — the same override the atomic's systemd_service_path
# input argument exists for. Just dropping the unit file (comm=bash) fires
# the watch; we deliberately do not enable/start it.
# shellcheck source=detection/tests/_lib.sh
# shellcheck disable=SC2034,SC2329  # metadata vars + trigger/cleanup are consumed/invoked by _lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

TEST_NAME="systemd-user-unit"
TEST_SOURCE="auditd"
ART_TECHNIQUE="T1543.002"
ART_ATOMIC="d9e4f24f-aa67-4c6e-bcbf-85622b697a7c (Create Systemd Service) — path override: user unit dir"
REQUIRES_SUDO=0
EXPECT_RULES=("Systemd User Unit Created Or Modified")

_UNIT_DIR="${HOME}/.config/systemd/user"
_UNIT="${_UNIT_DIR}/art-detection-test.service"
_DIR_CREATED=0

trigger() {
  if [ ! -d "${_UNIT_DIR}" ]; then
    _DIR_CREATED=1
    mkdir -p "${_UNIT_DIR}"
  fi
  {
    echo "[Unit]"
    echo "Description=Atomic Red Team detection test T1543.002"
    echo "[Service]"
    echo "ExecStart=/bin/true"
    echo "[Install]"
    echo "WantedBy=default.target"
  } >"${_UNIT}"
}

cleanup() {
  rm -f "${_UNIT}"
  # Only remove the dir if this test created it and it's now empty.
  if [ "${_DIR_CREATED}" -eq 1 ]; then
    rmdir "${_UNIT_DIR}" 2>/dev/null || true
  fi
}

run_atomic_test
