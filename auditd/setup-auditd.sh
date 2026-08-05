#!/usr/bin/env bash
set -euo pipefail

# Install auditd tamper-detection watches (see *.rules in this directory).
# Idempotent: re-running re-renders and reloads.
#
# Every auditd/*.rules file is installed into /etc/audit/rules.d/, so new
# watch categories are added by dropping a file here — no script changes.
# Files containing @HOME@ are rendered for the invoking user and installed
# under a username-suffixed name, so multiple users on one machine can each
# run this without overwriting each other's rules.
#
# Root-owned copies, never symlinks into the repo: audit config sourced
# from a user-writable path would let any process running as the user
# silently remove the watches on itself.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULES_DIR="/etc/audit/rules.d"
RUN_USER="$(id -un)"

# Drift-aware: only write and reload when content differs. This runs from
# `make update`, and an unconditional rewrite would fire our own
# audit-config-tamper watch on every routine update — noise that trains you
# to ignore the alert.
changed=0
tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT

for src in "${SCRIPT_DIR}"/*.rules; do
  base="$(basename "${src}")"
  if grep -q '@HOME@' "${src}"; then
    dst="${RULES_DIR}/${base%.rules}-${RUN_USER}.rules"
    sed "s|@HOME@|${HOME}|g" "${src}" >"${tmp}"
  else
    dst="${RULES_DIR}/${base}"
    cp "${src}" "${tmp}"
  fi
  if sudo cmp -s "${tmp}" "${dst}" 2>/dev/null; then
    echo "[*] ${dst} up to date"
  else
    echo "[*] Installing ${dst}"
    sudo install -m 0640 "${tmp}" "${dst}"
    changed=1
  fi
done

# Fedora's stock audit.rules ships `-a task,never`, which disables syscall
# auditing for every process started while it is in effect — file watches
# are syscall-based, so they silently never fire. Comment it out. The audit
# RPM won't overwrite a modified config on update (it lands as .rpmnew).
STOCK_RULES="/etc/audit/rules.d/audit.rules"
if sudo grep -q '^-a task,never' "${STOCK_RULES}"; then
  echo "[*] Disabling '-a task,never' in ${STOCK_RULES} (suppresses all file watches)..."
  sudo sed -i 's|^-a task,never|## disabled by setup-auditd.sh — suppresses syscall auditing, so file watches never fire\n#-a task,never|' "${STOCK_RULES}"
  changed=1
fi

if [ "${changed}" -eq 1 ]; then
  echo "[*] Loading rules..."
  sudo augenrules --load
  echo "[!] Note: processes already running keep their no-audit flag;"
  echo "    new processes are audited now, a reboot covers everything."
else
  echo "[*] No rule changes — skipping reload."
fi

# Widen audit-log read access to the local admin group so ausearch/lnav work
# without sudo. Read-only: the log stays root-writable. auditd applies
# log_group to files it creates and rotates; the chgrp/chmod below covers the
# existing ones. Deliberate trade: anyone in that group can read the audit trail.
#
# The group is per-distro. Fedora's admin group is wheel; Debian/Ubuntu have no
# wheel at all and use adm for log reading — /var/log/audit already ships as
# root:adm there, so this is the native answer rather than a substitute.
case "$("${SCRIPT_DIR}/../common/detect-distro.sh")" in
  fedora) LOG_GROUP="wheel" ;;
  ubuntu) LOG_GROUP="adm" ;;
  *) LOG_GROUP="" ;;
esac

# Validate before writing. auditd refuses to start on an unresolvable log_group
# ("Group ID is non-numeric and unknown"), exiting 6/NOTCONFIGURED — so an
# unchecked name here does not degrade to a warning, it takes the daemon down
# and stops all audit logging until someone edits auditd.conf by hand. That is
# exactly what a hardcoded "wheel" did on Ubuntu, and it stayed invisible for
# eight days because the chgrp below failed first under `set -e` and masked the
# health check at the end of this script.
if [ -z "${LOG_GROUP}" ] || ! getent group "${LOG_GROUP}" >/dev/null; then
  echo "[!] No usable audit-log group for this host." >&2
  [ -n "${LOG_GROUP}" ] && echo "    '${LOG_GROUP}' does not exist in /etc/group." >&2
  echo "    Refusing to write log_group into auditd.conf: an unresolvable" >&2
  echo "    group stops auditd from starting at all." >&2
  exit 1
fi

if ! sudo grep -qE "^log_group = ${LOG_GROUP}$" /etc/audit/auditd.conf; then
  echo "[*] Setting log_group = ${LOG_GROUP} in auditd.conf..."
  sudo sed -i "s/^log_group = .*/log_group = ${LOG_GROUP}/" /etc/audit/auditd.conf
  # Restart rather than HUP: a daemon already dead from a bad config ignores
  # HUP, which would leave this script reporting success over a stopped auditd.
  sudo systemctl restart auditd
fi

# Checked unconditionally, not just after a config change. auditd being down is
# the failure that matters — the tamper watches record nothing — and it can
# happen for reasons this script never touched.
if ! systemctl is-active --quiet auditd; then
  echo "[!] auditd is not running — no audit events are being recorded." >&2
  echo "    systemctl status auditd; journalctl -u auditd -n 20" >&2
  exit 1
fi
if [ "$(sudo stat -c '%G' /var/log/audit)" != "${LOG_GROUP}" ]; then
  echo "[*] Granting ${LOG_GROUP} read access to existing logs..."
  sudo chgrp -R "${LOG_GROUP}" /var/log/audit
  sudo chmod 0750 /var/log/audit
  sudo find /var/log/audit -type f -exec chmod 0640 {} +
fi

echo "[*] Active tamper watches:"
if ! sudo auditctl -l | grep -E -- '-k [a-z-]+-tamper'; then
  echo "[!] No tamper rules active — is auditd running?"
  echo "    systemctl status auditd"
  exit 1
fi

echo ""
echo "[*] Done. Useful commands (aliases from modules/shell.nix; log is"
echo "    wheel-readable, so no sudo needed):"
echo "      tamper                      — today's tamper events, interpreted"
echo "      tampernew                   — only tamper events since you last looked"
echo "      tamperlog                   — browse the raw log in lnav, filtered"
echo "      make sigma-scan             — run Sigma rules (detection/rules/) over the log"
echo "      aureport -k --summary       — event counts per key"
