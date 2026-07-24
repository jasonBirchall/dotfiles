#!/usr/bin/env bash
# ATT&CK T1546.004 — .bashrc/.bash_profile persistence.
# ART atomic 0a898315-4cfa-4007-bafe-33a4646d115f ("Add command to .bashrc")
# appends to ~/.bashrc. On this machine that file is a home-manager symlink
# into the read-only nix store, so an in-place append gets EACCES and
# produces no audit event at all. The real tamper vector here is replacing
# the managed symlink, so this test does that (rm + recreate) — the unlink
# fires the rc-tamper watch with a non-allowlisted comm (rm).
# shellcheck source=detection/tests/_lib.sh
# shellcheck disable=SC2034,SC2329  # metadata vars + trigger/cleanup are consumed/invoked by _lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

TEST_NAME="rc-symlink-replace"
TEST_SOURCE="auditd"
ART_TECHNIQUE="T1546.004"
ART_ATOMIC="0a898315-4cfa-4007-bafe-33a4646d115f (Add command to .bashrc) — adapted: symlink replace"
REQUIRES_SUDO=0
EXPECT_RULES=("Shell RC File Modified By Unexpected Process")

_RC="${HOME}/.bashrc"
_RC_TARGET=""

trigger() {
  # Only meaningful if ~/.bashrc is the expected nix-managed symlink.
  if [ ! -L "${_RC}" ]; then
    echo "  [!] ${_RC} is not a symlink — skipping to avoid clobbering a real file" >&2
    return 1
  fi
  _RC_TARGET="$(readlink "${_RC}")"
  rm "${_RC}"
  ln -s "${_RC_TARGET}" "${_RC}"
}

cleanup() {
  # Restore the exact symlink if the trigger left it missing or altered.
  if [ -n "${_RC_TARGET}" ] && [ "$(readlink "${_RC}" 2>/dev/null)" != "${_RC_TARGET}" ]; then
    rm -f "${_RC}"
    ln -s "${_RC_TARGET}" "${_RC}"
  fi
}

run_atomic_test
