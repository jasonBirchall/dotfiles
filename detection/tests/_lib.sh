#!/usr/bin/env bash
# Shared runner for detection tests. Each test in this directory replicates
# an Atomic Red Team Linux atomic (adapted to the paths this machine's
# auditd watches actually cover), fires it, scans with sigma-scan.sh, and
# asserts the expected rule(s) matched events produced *after* the trigger.
#
# A test file sets a few variables, defines trigger()/cleanup(), then calls
# run_atomic_test. cleanup() always runs (EXIT trap) so a failed trigger
# still restores state. Tests are individually runnable:
#   bash detection/tests/rc_symlink_replace.sh
# or in bulk via detection/run-tests.sh.
#
# Contract (set before calling run_atomic_test):
#   TEST_NAME       short id, e.g. "rc-symlink-replace"
#   TEST_SOURCE     telemetry source / rules subdir, e.g. "auditd"
#   ART_TECHNIQUE   MITRE ATT&CK id, e.g. "T1546.004"
#   ART_ATOMIC      atomic GUID + name (or "no ART atomic — <reason>")
#   REQUIRES_SUDO   1 if the trigger needs root (skipped unless RUN_SUDO_TESTS=1)
#   EXPECT_RULES    array of rule *titles* expected to fire
#   trigger()       performs the action
#   cleanup()       restores state; must be idempotent

set -euo pipefail

_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECTION_DIR="$(cd "${_TESTS_DIR}/.." && pwd)"

_c_pass=$'\033[32m'
_c_fail=$'\033[31m'
_c_skip=$'\033[33m'
_c_dim=$'\033[2m'
_c_off=$'\033[0m'

# Run sigma-scan.sh for a source and echo the findings JSON path it wrote.
_findings_for() {
  local source="$1" out
  out="$("${DETECTION_DIR}/sigma-scan.sh" "${source}" 2>/dev/null)"
  sed -n 's/.*findings: //p' <<<"${out}" | tail -1
}

# True if TITLE has at least one match at or after START (both timestamps in
# Zircolite's "%Y-%m-%d %H:%M:%S" local format, which sorts chronologically).
_rule_fired() {
  local findings="$1" start="$2" title="$3" n
  n="$(jq --arg s "${start}" --arg t "${title}" \
    '[.[] | select(.title == $t) | .matches[] | select(.timestamp >= $s)] | length' \
    "${findings}")"
  [ "${n:-0}" -gt 0 ]
}

run_atomic_test() {
  printf '%s┌─ %s%s  %s[%s]%s\n' \
    "${_c_dim}" "${TEST_NAME}" "${_c_off}" \
    "${_c_dim}" "${ART_TECHNIQUE}" "${_c_off}"

  if [ "${REQUIRES_SUDO:-0}" -eq 1 ] && [ "${RUN_SUDO_TESTS:-0}" -ne 1 ]; then
    printf '└─ %sSKIP%s needs sudo — re-run with: make sigma-test SUDO=1\n\n' \
      "${_c_skip}" "${_c_off}"
    exit 2
  fi

  trap 'cleanup || true' EXIT

  local start findings ok=1 title
  start="$(date '+%Y-%m-%d %H:%M:%S')"
  trigger
  findings="$(_findings_for "${TEST_SOURCE}")"
  if [ -z "${findings}" ] || [ ! -f "${findings}" ]; then
    printf '└─ %sFAIL%s scan produced no findings file\n\n' "${_c_fail}" "${_c_off}"
    exit 1
  fi

  for title in "${EXPECT_RULES[@]}"; do
    if _rule_fired "${findings}" "${start}" "${title}"; then
      printf '│  %s✓%s %s\n' "${_c_pass}" "${_c_off}" "${title}"
    else
      printf '│  %s✗%s %s %s(no match after trigger)%s\n' \
        "${_c_fail}" "${_c_off}" "${title}" "${_c_dim}" "${_c_off}"
      ok=0
    fi
  done

  if [ "${ok}" -eq 1 ]; then
    printf '└─ %sPASS%s  %s\n\n' "${_c_pass}" "${_c_off}" "${findings}"
    exit 0
  else
    printf '└─ %sFAIL%s  %s\n\n' "${_c_fail}" "${_c_off}" "${findings}"
    exit 1
  fi
}
