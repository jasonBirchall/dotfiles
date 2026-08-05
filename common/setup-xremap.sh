#!/usr/bin/env bash
# Grant the current user permission to use /dev/uinput so xremap can run
# unprivileged as a systemd --user service.
set -euo pipefail

RULE_PATH="/etc/udev/rules.d/99-uinput.rules"
RULE_BODY='KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"'

if [ ! -f "$RULE_PATH" ] || ! grep -qF "$RULE_BODY" "$RULE_PATH"; then
  echo "Writing udev rule at $RULE_PATH"
  echo "$RULE_BODY" | sudo tee "$RULE_PATH" >/dev/null
  sudo udevadm control --reload-rules
  sudo udevadm trigger --subsystem-match=misc
else
  echo "udev rule already present at $RULE_PATH"
fi

if id -nG "$USER" | tr ' ' '\n' | grep -qx input; then
  echo "User $USER already in 'input' group"
else
  echo "Adding $USER to 'input' group"
  sudo usermod -aG input "$USER"
  echo "Log out and back in (or run 'newgrp input') for the new group to take effect."
fi

echo "xremap setup complete."
