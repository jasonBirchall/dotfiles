#!/usr/bin/env bash
# Install Firefox Nightly from Mozilla's apt repository.
#
# The Ubuntu half of `make firefox-nightly`; Fedora takes the tarball route in
# fedora/setup-firefox-nightly.sh. Nightly has no packaged option in the Ubuntu
# archive and is not on Flathub — Mozilla publishes only the release build
# there (org.mozilla.firefox, common/flatpaks.txt) — so this repo is the
# official channel, and unlike the tarball it updates with everything else.
#
# This adds a vendor apt repo, which common/flatpaks.txt argues against for
# Slack and Thunderbird. The reasoning there was that a vendor repo buys
# nothing when Flathub has the same build, and hides divergence between the two
# distros. Neither applies here: Flathub has no Nightly at all, and the two
# distros already diverge because Fedora has no equivalent repo. What the
# objection was really about — an update channel nothing in this repo can see —
# is the argument *for* apt over the tarball, since `make audit` and
# `make update` both reach apt.
#
# Idempotent: safe to re-run. Re-running also repairs a hand-edited sources or
# preferences file, since both are rewritten from here every time.
set -euo pipefail

KEYRING="/etc/apt/keyrings/packages.mozilla.org.asc"
SOURCES="/etc/apt/sources.list.d/mozilla.sources"
PREFS="/etc/apt/preferences.d/mozilla"

# Verified 2026-08-03. The uid on this key reads "Artifact Registry Repository
# Signer <artifact-registry-repository-signer@google.com>" rather than anything
# saying Mozilla, because the repo is hosted on Google Artifact Registry. That
# is expected — the fingerprint is the thing to check, and it is the one
# Mozilla documents.
KEY_FPR="35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3"
# Served ASCII-armored despite the .gpg name, hence the .asc keyring filename:
# apt reads armored keys only from .asc, and fails the repo silently otherwise.
KEY_URL="https://packages.mozilla.org/apt/repo-signing-key.gpg"

command -v curl >/dev/null 2>&1 || {
  echo "[!] curl is required but not installed." >&2
  exit 1
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "[*] Fetching Mozilla's repository signing key…"
curl -sSfL -m 60 -o "$WORK/mozilla.asc" "$KEY_URL"

# Check the fingerprint before the key is anywhere apt can see it. Installing
# first and verifying after would leave a window where a wrong key is trusted.
echo "[*] Verifying key fingerprint…"
GOT="$(gpg --show-keys --with-colons "$WORK/mozilla.asc" 2>/dev/null | awk -F: '/^fpr:/ { print $10; exit }')"
if [ "$GOT" != "$KEY_FPR" ]; then
  echo "[!] Key fingerprint mismatch — refusing to add the repository." >&2
  echo "    expected: $KEY_FPR" >&2
  echo "    got:      ${GOT:-<none>}" >&2
  exit 1
fi
echo "    $KEY_FPR OK."

sudo install -d -m 0755 /etc/apt/keyrings
sudo install -m 0644 "$WORK/mozilla.asc" "$KEYRING"

echo "[*] Writing $SOURCES…"
sudo tee "$SOURCES" >/dev/null <<EOF
# Managed by ubuntu/setup-firefox-nightly.sh — edits will be overwritten.
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: $KEYRING
EOF

# This repo carries the whole Firefox family, not just Nightly, and Mozilla's
# own documented pin is `Package: *` at priority 1000 — which would hand it
# every one of those names. That would quietly undo the release-Firefox move to
# Flathub: apt would offer Mozilla's `firefox` deb, and priority beats version,
# so it would win over Ubuntu's package despite the lower version number.
#
# So: Nightly is pinned up, and every other package this origin serves is
# pinned below the "never install" threshold. Nothing here can be pulled in by
# accident; only the one package that was actually asked for.
echo "[*] Writing $PREFS…"
sudo tee "$PREFS" >/dev/null <<'EOF'
# Managed by ubuntu/setup-firefox-nightly.sh — edits will be overwritten.
Package: firefox-nightly
Pin: origin packages.mozilla.org
Pin-Priority: 1000

# Release Firefox is a flatpak (common/flatpaks.txt). A negative priority means
# apt will not install these even if something asks for them by name.
Package: firefox firefox-esr firefox-beta firefox-devedition mozillavpn
Pin: origin packages.mozilla.org
Pin-Priority: -1
EOF

echo "[*] Refreshing the apt index…"
sudo apt-get update -qq

echo "[*] Installing firefox-nightly…"
sudo apt-get install -y firefox-nightly

VERSION="$(dpkg-query -W -f='${Version}' firefox-nightly 2>/dev/null || echo unknown)"
echo ""
echo "[*] Firefox Nightly $VERSION installed."
echo ""
# shellcheck disable=SC2016  # the backticks are prose, not a substitution
echo '    Updates arrive with `make update` / unattended-upgrades, like any'
echo "    other apt package."
echo ""

# Ubuntu's `firefox` deb is a transitional package whose postinst installs
# Canonical's snap. Removing the snap does not remove it, so it sits there
# until something upgrades it — at which point the postinst runs again and the
# snap comes back, silently undoing the move to Flathub.
if dpkg-query -W -f='${Status}' firefox 2>/dev/null | grep -q "install ok installed"; then
  echo "    Note: Ubuntu's transitional 'firefox' deb is still installed."
  echo "    Its only job is to install the Firefox snap, and it will do so"
  echo "    again the next time apt upgrades it. Remove it (this does not"
  echo "    touch the flatpak or Nightly):"
  echo "      sudo apt remove firefox"
  echo ""
fi
