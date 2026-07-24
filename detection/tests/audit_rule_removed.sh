#!/usr/bin/env bash
# ATT&CK T1685.004 — Disable or Modify Linux Audit System.
# No ART atomic. Deletes the rc-tamper watch from the running kernel ruleset
# with `auditctl -W`, which emits a CONFIG_CHANGE remove_rule carrying the
# tamper key — the exact "someone is blinding the watches" signal. Restores
# the full known-good ruleset from disk with augenrules afterwards. Requires
# sudo; skipped unless RUN_SUDO_TESTS=1.
# shellcheck source=detection/tests/_lib.sh
# shellcheck disable=SC2034,SC2329  # metadata vars + trigger/cleanup are consumed/invoked by _lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

TEST_NAME="audit-rule-removed"
TEST_SOURCE="auditd"
ART_TECHNIQUE="T1685.004"
ART_ATOMIC="no ART atomic — auditctl -W watch delete"
REQUIRES_SUDO=1
EXPECT_RULES=("Auditd Tamper Watch Rule Removed")

trigger() {
  # -W removes a previously added watch and logs a remove_rule event.
  sudo auditctl -W "${HOME}/.bashrc" -p wa -k rc-tamper
}

cleanup() {
  # Reload every rule from rules.d so the watch set matches disk regardless
  # of what the trigger changed.
  sudo augenrules --load >/dev/null 2>&1 || true
}

run_atomic_test
