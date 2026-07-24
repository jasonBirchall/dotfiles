#!/usr/bin/env bash
# No direct ART atomic — exercises the defensive "failed write to a watched
# path" rule. Temporarily drops write permission on ~/.ssh and attempts to
# create a file there as the owner; the openat fails with EACCES, producing
# a SYSCALL record with success=no under the ssh-tamper watch. Models a
# confined or unprivileged process probing at protected dotfiles.
# shellcheck source=detection/tests/_lib.sh
# shellcheck disable=SC2034,SC2329  # metadata vars + trigger/cleanup are consumed/invoked by _lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

TEST_NAME="failed-access"
TEST_SOURCE="auditd"
ART_TECHNIQUE="T1083"
ART_ATOMIC="no ART atomic — defensive rule, synthetic EACCES probe"
REQUIRES_SUDO=0
EXPECT_RULES=("Failed Write To Tamper-Watched Path")

_SSH="${HOME}/.ssh"
_MODE=""

trigger() {
  mkdir -p "${_SSH}"
  _MODE="$(stat -c '%a' "${_SSH}")"
  chmod 500 "${_SSH}"
  # Expected to fail with EACCES — that failure is the signal.
  touch "${_SSH}/.detection-canary" 2>/dev/null || true
  chmod "${_MODE}" "${_SSH}"
}

cleanup() {
  # Restore perms even if the trigger aborted before it could, and clear the
  # canary if the write somehow succeeded.
  if [ -n "${_MODE}" ]; then
    chmod "${_MODE}" "${_SSH}" 2>/dev/null || true
  fi
  rm -f "${_SSH}/.detection-canary" 2>/dev/null || true
}

run_atomic_test
