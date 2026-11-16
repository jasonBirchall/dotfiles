#!/usr/bin/env bash
# Let sudo accept Touch ID, including inside tmux.
#
# macOS includes /etc/pam.d/sudo_local from /etc/pam.d/sudo and keeps it
# across system updates, so this writes that one file:
#
#   auth  optional    /usr/local/lib/pam/pam_reattach.so ignore_ssh
#   auth  sufficient  pam_tid.so
#
# pam_tid is Apple's Touch ID module. On its own it cannot show its prompt
# from inside tmux, because the tmux server sits outside the GUI session;
# pam_reattach moves sudo back into it first. "sufficient" means a fingerprint
# is enough, and the password still works when there is no sensor to touch
# (lid closed, ssh).
#
# pam_reattach comes from Home Manager (modules/packages.nix), but sudo is
# pointed at a root-owned copy under /usr/local/lib/pam, never at
# ~/.nix-profile or Homebrew. Both are writable by my user, and a PAM module
# that sudo loads from a user-writable path is root for anything running as
# me. Re-run this after pam-reattach is updated to refresh the copy.
#
# Safe to try: a root-owned guard removes sudo_local again unless a fresh
# `sudo` succeeds through the new configuration within two minutes.
#
# Usage: setup-touchid-sudo.sh            install (idempotent)
#        setup-touchid-sudo.sh --remove   put sudo back to password-only
set -euo pipefail

SUDO_LOCAL=/etc/pam.d/sudo_local
PAM_DIR=/usr/local/lib/pam
MODULE_SRC="$HOME/.nix-profile/lib/pam/pam_reattach.so"
MODULE_DST="$PAM_DIR/pam_reattach.so"
MARKER="# Managed by dotfiles: mac/setup-touchid-sudo.sh"
GUARD_SECONDS=120

die() {
  echo "[!] $*" >&2
  exit 1
}

[ "$(uname -s)" = Darwin ] || die "Touch ID for sudo is macOS-only."
[ "$(id -u)" -ne 0 ] || die "Run this as yourself, not with sudo: it tests your own sudo at the end."

# Never touch a sudo_local this script did not write.
if [ -e "$SUDO_LOCAL" ] && ! grep -qxF "$MARKER" "$SUDO_LOCAL"; then
  echo "[!] $SUDO_LOCAL exists and was not written by this script:" >&2
  sed 's/^/      /' "$SUDO_LOCAL" >&2
  die "Leaving it alone. Merge by hand, or remove it and re-run."
fi

if [ "${1:-}" = "--remove" ]; then
  echo "[*] Removing Touch ID for sudo (you will be asked to authenticate)..."
  sudo rm -f "$SUDO_LOCAL" "$MODULE_DST"
  echo "[*] Done. sudo is back to password-only."
  exit 0
fi
[ $# -eq 0 ] || die "Unknown argument: $1 (the only option is --remove)"

[ -f "$MODULE_SRC" ] || die "$MODULE_SRC is missing. Run 'make hm' first: pam-reattach comes from Home Manager."

# The copy is only as trustworthy as the directories above it.
for dir in /usr/local /usr/local/lib; do
  [ -d "$dir" ] || die "$dir does not exist."
  [ "$(stat -f '%Su' "$dir")" = root ] || die "$dir is not owned by root; refusing to put a PAM module under it."
  mode="$(stat -f '%Lp' "$dir")"
  [ $((0$mode & 022)) -eq 0 ] || die "$dir is writable by group or others (mode $mode); refusing to put a PAM module under it."
done

if ! bioutil -r 2>/dev/null | grep -q 'Biometrics for unlock: 1'; then
  echo "[!] Touch ID does not look enrolled for unlock. Continuing; sudo will just keep asking for the password until it is."
fi

echo "[*] Authenticate once with your password to install..."
sudo -v

echo "[*] Copying pam_reattach to $MODULE_DST (root-owned)..."
sudo install -d -o root -g wheel -m 755 "$PAM_DIR"
sudo install -o root -g wheel -m 444 "$MODULE_SRC" "$MODULE_DST"

staged="$(mktemp)"
trap 'rm -f "$staged"' EXIT
cat >"$staged" <<EOF
# sudo_local: local config file which survives system update and is included for sudo
$MARKER
auth       optional       $MODULE_DST ignore_ssh
auth       sufficient     pam_tid.so
EOF

# Start the guard before the file goes live, while the cached credential is
# still good. If the new configuration breaks sudo, nothing below can run as
# root any more; the guard can, and it undoes the change.
sudo sh -c "sleep $GUARD_SECONDS; rm -f '$SUDO_LOCAL'" &
guard=$!

echo "[*] Writing $SUDO_LOCAL..."
sudo install -o root -g wheel -m 444 "$staged" "$SUDO_LOCAL"

echo "[*] Testing with a fresh sudo. A Touch ID prompt should appear now."
sudo -k
if sudo true; then
  sudo kill "$guard" 2>/dev/null || true
  if [ -e "$SUDO_LOCAL" ]; then
    echo ""
    echo "[*] Touch ID for sudo is on."
    echo "    If you were asked for the password instead of a fingerprint, it is"
    echo "    installed but Touch ID did not engage; try 'sudo -k; sudo true' again."
    echo "    Undo with: bash mac/setup-touchid-sudo.sh --remove"
  else
    echo "[!] sudo worked, but only after the $GUARD_SECONDS-second guard had already removed $SUDO_LOCAL. Re-run and answer the prompt sooner."
    exit 1
  fi
else
  echo "[!] sudo failed through the new configuration." >&2
  echo "    The guard removes $SUDO_LOCAL within $GUARD_SECONDS seconds; waiting for it..." >&2
  wait "$guard" 2>/dev/null || true
  [ -e "$SUDO_LOCAL" ] && die "$SUDO_LOCAL is still there. Remove it from Finder (Go > Go to Folder > /etc/pam.d), which asks for an admin password."
  die "Rolled back. sudo is password-only again."
fi
