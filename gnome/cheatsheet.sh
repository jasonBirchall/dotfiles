#!/usr/bin/env bash
# Searchable cheatsheet of the GNOME / pop-shell keybindings — the GNOME
# analogue of sway/cheatsheet.sh. wofi is layer-shell-only and GNOME
# doesn't support layer-shell, so this opens a ghostty window running fzf.
# Reads live dconf state, so it lists what is actually bound: the keys
# managed in modules/gnome.nix plus anything set outside it.

set -euo pipefail

FZF="$HOME/.nix-profile/bin/fzf"

# Launched from the keybinding with no args: re-exec inside a terminal.
if [ "${1:-}" != "--list" ]; then
  exec ghostty --title="GNOME keybindings" -e "$0" --list
fi

{
  for dir in \
    /org/gnome/desktop/wm/keybindings/ \
    /org/gnome/shell/keybindings/ \
    /org/gnome/shell/extensions/pop-shell/ \
    /org/gnome/settings-daemon/plugins/media-keys/; do
    dconf dump "$dir" | awk '
      # Custom launchers live in [custom-keybindings/customN] subsections
      # with separate binding= / name= lines; pair them up.
      /^\[.*custom[0-9]+\]$/ { custom = 1; binding = ""; name = ""; next }
      /^\[/ { custom = 0; next }
      custom && /^binding=/ { binding = substr($0, 9); gsub(/\x27/, "", binding) }
      custom && /^name=/ { name = substr($0, 6); gsub(/\x27/, "", name) }
      custom && binding != "" && name != "" {
        printf "%-30s  %s\n", binding, name
        binding = ""; name = ""
      }
      # Ordinary accelerator lists: key=[<Super>x, ...]
      !custom && /^[a-z0-9-]+=\[.+\]$/ {
        eq = index($0, "=")
        key = substr($0, 1, eq - 1)
        val = substr($0, eq + 1)
        if (val !~ /</ && val !~ /XF86|Print/) next
        gsub(/[][\x27]/, "", val)
        printf "%-30s  %s\n", val, key
      }
    '
  done
  # pop-shell adjustment mode: entered with <Super>r (sway resize mode),
  # its inner keys are hardcoded in the extension rather than dconf.
  printf '[adjust] %-21s  %s\n' "h/j/k/l or arrows" "move window"
  printf '[adjust] %-21s  %s\n' "Shift+direction" "resize window"
  printf '[adjust] %-21s  %s\n' "Ctrl+direction" "swap with neighbour"
  printf '[adjust] %-21s  %s\n' "Return / Escape" "apply / cancel"
} | "$FZF" --prompt="gnome > " --no-sort --layout=reverse >/dev/null || true
