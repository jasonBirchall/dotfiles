#!/usr/bin/env bash
set -euo pipefail

# Reports whether a newer Proton Drive CLI has shipped than the one pinned in
# modules/services.nix. Called by `make audit`. Proton has no nixpkgs package,
# no GitHub releases, and no "latest" URL, so we scrape the version off their
# download index page and compare against the installed binary.
#
# When behind, it downloads the new linux-x64 build once to compute the SHA-512
# and prints the exact VER + SHA512 lines to paste into the protonDriveCli
# activation — so bumping the pin is copy-paste, then `make hm`.

INDEX_URL="https://proton.me/download/drive/cli/index.html"
BIN="${PROTON_DRIVE_BIN:-$HOME/.local/bin/proton-drive}"

installed="(not installed)"
if [ -x "$BIN" ]; then
  installed="$("$BIN" --version 2>/dev/null | grep -oE 'cli-drive@[0-9.]+' | cut -d@ -f2 || true)"
fi

latest="$(curl -fsSL "$INDEX_URL" 2>/dev/null | grep -oE 'cli/[0-9]+\.[0-9]+\.[0-9]+/' | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)"

if [ -z "$latest" ]; then
  echo "could not determine latest version (offline, or page layout changed)"
  exit 0
fi

echo "installed: ${installed:-unknown}    latest: $latest"

if [ "$installed" = "$latest" ]; then
  echo "up to date."
  exit 0
fi

echo "-> newer version available. Fetching checksum for the pin…"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
if ! curl -fsSL "https://proton.me/download/drive/cli/$latest/linux-x64/proton-drive" -o "$tmp"; then
  echo "   (download failed — check the version manually at $INDEX_URL)"
  exit 0
fi
sha="$(sha512sum "$tmp" | cut -d' ' -f1)"

cat <<EOF
   Update modules/services.nix (protonDriveCli) to:
     VER=$latest
     SHA512=$sha
   then run: make hm
EOF
