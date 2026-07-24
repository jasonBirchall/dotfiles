#!/usr/bin/env bash
# ATT&CK T1685.004 — Disable or Modify Linux Audit System.
# No ART atomic targets /etc/audit specifically. This drops a canary file
# into /etc/audit via `touch` (not in the provisioning allowlist), which
# fires the audit-config watch. Requires sudo; skipped unless RUN_SUDO_TESTS=1.
# shellcheck source=detection/tests/_lib.sh
# shellcheck disable=SC2034,SC2329  # metadata vars + trigger/cleanup are consumed/invoked by _lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

TEST_NAME="audit-config-write"
TEST_SOURCE="auditd"
ART_TECHNIQUE="T1685.004"
ART_ATOMIC="no ART atomic — synthetic write to /etc/audit"
REQUIRES_SUDO=1
EXPECT_RULES=("Audit Configuration Modified By Unexpected Process")

_CANARY="/etc/audit/.detection-test-canary"

trigger() {
  sudo touch "${_CANARY}"
}

cleanup() {
  sudo rm -f "${_CANARY}" 2>/dev/null || true
}

run_atomic_test
