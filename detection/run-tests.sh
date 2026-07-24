#!/usr/bin/env bash
set -euo pipefail

# Runs the detection tests in detection/tests/ and prints a PASS/FAIL/SKIP
# summary. Each test replicates an Atomic Red Team Linux atomic (adapted to
# the paths this machine's watches cover), fires it, scans, and asserts the
# expected rule fired. Tests clean up after themselves.
#
# Usage:
#   run-tests.sh                 run the no-sudo tests
#   run-tests.sh --sudo          also run tests that need root (audit config)
#   run-tests.sh --list          list tests and their ART mapping, run nothing
#   run-tests.sh NAME [NAME...]  run only the named tests (basename, no .sh)

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)/tests"
RUN_SUDO=0
FILTERS=()

for arg in "$@"; do
  case "${arg}" in
    --sudo) RUN_SUDO=1 ;;
    --list) LIST=1 ;;
    -h | --help)
      sed -n '3,14p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) FILTERS+=("${arg}") ;;
  esac
done

mapfile -t tests < <(find "${TESTS_DIR}" -maxdepth 1 -name '*.sh' ! -name '_*' | sort)

_selected() {
  local name="$1"
  [ "${#FILTERS[@]}" -eq 0 ] && return 0
  local f
  for f in "${FILTERS[@]}"; do [ "${f}" = "${name}" ] && return 0; done
  return 1
}

# Pull a `KEY="..."` assignment out of a test file for the listing.
_meta() { sed -n "s/^$2=\"\\(.*\\)\"/\\1/p" "$1" | head -1; }

if [ "${LIST:-0}" -eq 1 ]; then
  printf '%-22s %-10s %s\n' "TEST" "TECHNIQUE" "ATOMIC"
  for t in "${tests[@]}"; do
    printf '%-22s %-10s %s\n' \
      "$(basename "${t}" .sh)" "$(_meta "${t}" ART_TECHNIQUE)" "$(_meta "${t}" ART_ATOMIC)"
  done
  exit 0
fi

pass=0 fail=0 skip=0
declare -a failed=()

for t in "${tests[@]}"; do
  name="$(basename "${t}" .sh)"
  _selected "${name}" || continue
  set +e
  RUN_SUDO_TESTS="${RUN_SUDO}" bash "${t}"
  rc=$?
  set -e
  case "${rc}" in
    0) pass=$((pass + 1)) ;;
    2) skip=$((skip + 1)) ;;
    *)
      fail=$((fail + 1))
      failed+=("${name}")
      ;;
  esac
done

echo "──────────────────────────────────────────"
printf 'Detection tests: %d passed, %d failed, %d skipped\n' "${pass}" "${fail}" "${skip}"
if [ "${fail}" -gt 0 ]; then
  printf 'Failed: %s\n' "${failed[*]}"
  exit 1
fi
