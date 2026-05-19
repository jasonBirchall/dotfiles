#!/usr/bin/env bash
set -euo pipefail

# Install recon's systemd --user units. Symlinks unit files from this repo
# into ~/.config/systemd/user/ so edits in the repo are picked up directly,
# then enables + starts each timer. Idempotent — safe to re-run after
# adding new recon-*.timer files under any tool's directory.

RECON_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_UNIT_DIR="$HOME/.config/systemd/user"

mkdir -p "$USER_UNIT_DIR"

shopt -s nullglob

units=(
  "$RECON_DIR"/recon-notify@.service
  "$RECON_DIR"/*/recon-*.service
  "$RECON_DIR"/*/recon-*.timer
)

for src in "${units[@]}"; do
  name=$(basename "$src")
  ln -sfn "$src" "$USER_UNIT_DIR/$name"
  echo "linked $name -> $src"
done

systemctl --user daemon-reload

for timer in "$RECON_DIR"/*/recon-*.timer; do
  name=$(basename "$timer")
  systemctl --user enable --now "$name"
done

echo
echo "Active recon timers:"
systemctl --user list-timers 'recon-*' --no-pager
