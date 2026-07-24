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

# Widen audit-log read access to wheel so ausearch/lnav work without sudo.
# Read-only: the log stays root-writable. auditd applies log_group to files
# it creates and rotates; the chgrp/chmod below covers the existing ones.
# Deliberate trade: anyone in wheel can read the audit trail.
LOG_GROUP="wheel"
if ! sudo grep -qE "^log_group = ${LOG_GROUP}$" /etc/audit/auditd.conf; then
  echo "[*] Setting log_group = ${LOG_GROUP} in auditd.conf..."
  sudo sed -i "s/^log_group = .*/log_group = ${LOG_GROUP}/" /etc/audit/auditd.conf
  sudo systemctl kill --signal=HUP auditd
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
echo "[*] Done. Useful commands:"
echo "      sudo ausearch -k ssh-tamper -i           — who touched ~/.ssh"
echo "      sudo ausearch -k rc-tamper -ts today -i  — shell rc changes today"
echo "      sudo aureport -k --summary               — event counts per key"
