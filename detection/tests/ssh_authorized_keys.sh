#!/usr/bin/env bash
# ATT&CK T1098.004 — SSH authorized_keys persistence.
# ART atomic 342cc723-127c-4d3a-8292-9c0c6b4ecadc ("Modify SSH Authorized
# Keys") only rewrites authorized_keys if it already exists; this test
# creates it first (backing up any real one) then appends a canary key via
# a shell redirect. Writing through bash means comm=bash — not in the ssh
# rule's allowlist — so both ssh-tamper rules fire.
# shellcheck source=detection/tests/_lib.sh
# shellcheck disable=SC2034,SC2329  # metadata vars + trigger/cleanup are consumed/invoked by _lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

TEST_NAME="ssh-authorized-keys"
TEST_SOURCE="auditd"
ART_TECHNIQUE="T1098.004"
ART_ATOMIC="342cc723-127c-4d3a-8292-9c0c6b4ecadc (Modify SSH Authorized Keys)"
REQUIRES_SUDO=0
EXPECT_RULES=(
  "SSH authorized_keys Written Or Deleted"
  "SSH Directory Modified By Unexpected Process"
)

_AK="${HOME}/.ssh/authorized_keys"
_AK_BAK=""
_AK_CREATED=0

trigger() {
  mkdir -p "${HOME}/.ssh"
  if [ -f "${_AK}" ]; then
    _AK_BAK="$(mktemp)"
    cp -p "${_AK}" "${_AK_BAK}"
  else
    _AK_CREATED=1
    : >"${_AK}"
    chmod 600 "${_AK}"
  fi
  echo 'ssh-ed25519 AAAAC3TESTdetectioncanary art@T1098.004' >>"${_AK}"
}

cleanup() {
  if [ "${_AK_CREATED}" -eq 1 ]; then
    rm -f "${_AK}"
  elif [ -n "${_AK_BAK}" ] && [ -f "${_AK_BAK}" ]; then
    cp -p "${_AK_BAK}" "${_AK}"
    rm -f "${_AK_BAK}"
  fi
}

run_atomic_test
