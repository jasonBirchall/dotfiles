#!/usr/bin/env bash
set -euo pipefail

# On-demand Sigma scan of local telemetry using Zircolite
# (https://github.com/wagga40/Zircolite). Collection is per-tool (auditd/,
# suricata/, ...); detection lives here. Rules are grouped by logsource in
# detection/rules/<source>/, and SOURCES below maps each one to its
# Zircolite input flag and default log path — adding a telemetry source is
# a rules directory plus one table entry, no new scripts.
#
# Rules are written per *record* against the raw field names Zircolite
# flattens to (type, key, comm, name, ...) — no pySigma pipeline involved.
#
# No sudo needed for auditd: setup-auditd.sh grants wheel read access.
# Zircolite isn't on PyPI, so it's cloned once and run via uv against its
# requirements file; `uv run` keeps the environment cached between runs.
#
# Usage: sigma-scan.sh [source] [log-file-or-directory]
#   no args         scan every source with rules and a readable log
#   sigma-scan.sh auditd /path/audit.log   one source, explicit log

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULES_ROOT="${SCRIPT_DIR}/rules"
ZIRCOLITE_DIR="${ZIRCOLITE_DIR:-${HOME}/.local/share/zircolite}"
OUT_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/sigma-scan"

# <source>: "<zircolite input flag>|<default log path>"
declare -A SOURCES=(
  [auditd]="--auditd|/var/log/audit/audit.log"
)

if [ ! -f "${ZIRCOLITE_DIR}/zircolite.py" ]; then
  echo "[*] Zircolite not found — cloning to ${ZIRCOLITE_DIR}..."
  git clone --depth 1 https://github.com/wagga40/Zircolite "${ZIRCOLITE_DIR}"
fi
mkdir -p "${OUT_DIR}"

scan_source() {
  local source="$1" log="$2"
  local input_flag="${SOURCES[${source}]%%|*}"
  local outfile
  outfile="${OUT_DIR}/findings-${source}-$(date +%Y%m%dT%H%M%S).json"

  echo "[*] Scanning ${source}: ${log}"
  # Run from OUT_DIR so Zircolite's working files (log, tmp db) land in
  # state, not wherever the scan was invoked from.
  (
    cd "${OUT_DIR}"
    uv run --with-requirements "${ZIRCOLITE_DIR}/requirements.txt" \
      python3 "${ZIRCOLITE_DIR}/zircolite.py" \
      "${input_flag}" \
      --config "${ZIRCOLITE_DIR}/config/config.yaml" \
      --events "${log}" \
      --ruleset "${RULES_ROOT}/${source}" \
      --outfile "${outfile}" \
      --logfile "${OUT_DIR}/zircolite.log"
  )
  echo "[*] ${source} findings: ${outfile}"
}

known_sources() {
  echo "${!SOURCES[@]}"
}

if [ $# -ge 1 ]; then
  source="$1"
  if [ -z "${SOURCES[${source}]:-}" ] || [ ! -d "${RULES_ROOT}/${source}" ]; then
    echo "[!] Unknown source '${source}' (known: $(known_sources))" >&2
    exit 1
  fi
  log="${2:-${SOURCES[${source}]##*|}}"
  if [ ! -r "${log}" ]; then
    echo "[!] Cannot read ${log}." >&2
    [ "${source}" = auditd ] &&
      echo "    Run 'make auditd' first — it grants the wheel group read access." >&2
    exit 1
  fi
  scan_source "${source}" "${log}"
else
  scanned=0
  for dir in "${RULES_ROOT}"/*/; do
    source="$(basename "${dir}")"
    if [ -z "${SOURCES[${source}]:-}" ]; then
      echo "[!] ${dir} has no entry in the SOURCES table — skipping" >&2
      continue
    fi
    log="${SOURCES[${source}]##*|}"
    if [ ! -r "${log}" ]; then
      echo "[!] ${source}: cannot read ${log} — skipping" >&2
      continue
    fi
    scan_source "${source}" "${log}"
    scanned=$((scanned + 1))
  done
  if [ "${scanned}" -eq 0 ]; then
    echo "[!] Nothing scanned — no source had both rules and a readable log." >&2
    exit 1
  fi
fi

echo ""
echo "[*] Summary of a findings file:"
echo "      jq '.[] | {title, hits: (.matches | length)}' <findings.json>"
echo "    Drill down on auditd hits (aliases from modules/shell.nix):"
echo "      tamper      — today's tamper events, interpreted (ausearch)"
echo "      tampernew   — only tamper events since you last looked"
echo "      tamperlog   — browse the raw log in lnav, filtered to tamper keys"
echo "    Older finding: ausearch -k <key> -ts <timestamp from finding> -i"
