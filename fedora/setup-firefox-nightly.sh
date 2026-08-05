#!/usr/bin/env bash
# Install Firefox Nightly from Mozilla's tarball.
#
# The Fedora half of `make firefox-nightly`; Ubuntu takes the apt route in
# ubuntu/setup-firefox-nightly.sh. Nightly is the one Firefox channel with no
# packaged option here: Flathub carries only the release build
# (org.mozilla.firefox, common/flatpaks.txt), there is no Mozilla flatpak repo
# — https://packages.mozilla.org/flatpak 404s — and Mozilla's yum repo is not
# the equal of their apt one. The tarball is the official channel.
#
# Installed under $HOME rather than /opt deliberately. Nightly's own updater
# rewrites files in place and only runs when the install directory is writable
# by the user running the browser. Under /opt it would sit at whatever version
# this script last fetched and never say so — which defeats the point of
# tracking nightly, and would land you back in exactly the silent-staleness
# hole that moved release Firefox off the snap (see common/flatpaks.txt).
#
# So this script runs once per host. After that the browser updates itself.
#
# Profiles do not collide with the release build: this reads ~/.mozilla/firefox
# and picks a profile keyed by install-directory hash, while release Firefox is
# a flatpak sandboxed to ~/.var/app/org.mozilla.firefox/.mozilla.
set -euo pipefail

PREFIX="${FIREFOX_NIGHTLY_PREFIX:-$HOME/.local/lib/firefox-nightly}"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
DESKTOP="$APPS_DIR/firefox-nightly.desktop"
LOCALE="${FIREFOX_NIGHTLY_LOCALE:-en-GB}"

# Mozilla Software Releases <release@mozilla.com>. Pinned rather than looked up
# by uid: binding the download to one known key is the entire value of the
# check, and a key fetched by name is whatever the keyserver felt like
# returning. Verified 2026-08-03 against keys.openpgp.org.
KEY_FPR="14F26682D0916CDD81E37B6D61B7B526D98F0353"
KEY_URL="https://keys.openpgp.org/vks/v1/by-fingerprint/$KEY_FPR"

# Mozilla's product-selector redirects to the current build, so the version
# never has to be hard-coded here.
DOWNLOAD_URL="https://download.mozilla.org/?product=firefox-nightly-latest-l10n-ssl&os=linux64&lang=$LOCALE"

for cmd in curl gpg tar; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "[!] $cmd is required but not installed." >&2
    exit 1
  }
done

WORK="$(mktemp -d)"
# GNUPGHOME inside the workdir so the pinned key is never added to the user's
# real keyring — this trust decision belongs to this script, not to gpg
# generally.
export GNUPGHOME="$WORK/gnupg"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
trap 'rm -rf "$WORK"' EXIT

echo "[*] Resolving the current Nightly build ($LOCALE)…"
# download.mozilla.org 302s to the real filename; resolve it first so the
# version being installed can be printed and the .asc fetched alongside.
TARBALL_URL="$(curl -sSfI -m 30 "$DOWNLOAD_URL" | awk 'tolower($1) == "location:" { print $2 }' | tr -d '\r')"
if [ -z "$TARBALL_URL" ]; then
  echo "[!] Could not resolve a download URL from $DOWNLOAD_URL" >&2
  echo "    Check that '$LOCALE' is a locale Mozilla builds Nightly for." >&2
  exit 1
fi
echo "    $(basename "$TARBALL_URL")"

echo "[*] Downloading tarball and signature…"
curl -sSfL -m 600 -o "$WORK/firefox.tar.xz" "$TARBALL_URL"
curl -sSfL -m 60 -o "$WORK/firefox.tar.xz.asc" "$TARBALL_URL.asc"

echo "[*] Verifying the signature against $KEY_FPR…"
curl -sSfL -m 60 -o "$WORK/mozilla.key" "$KEY_URL"
gpg --batch --quiet --import "$WORK/mozilla.key"
# --status-fd is what makes this a real check. Plain `gpg --verify` exits 0 for
# a good signature by ANY imported key, so on its own it would only prove the
# file was signed by something. GOODSIG carries the key id that actually signed.
if ! gpg --batch --status-fd 1 --verify "$WORK/firefox.tar.xz.asc" "$WORK/firefox.tar.xz" 2>/dev/null |
  grep -q "^\[GNUPG:\] VALIDSIG .*$KEY_FPR"; then
  echo "[!] Signature verification FAILED — refusing to install." >&2
  echo "    The tarball is not signed by Mozilla's release key." >&2
  exit 1
fi
echo "    Signature OK."

echo "[*] Extracting…"
tar -xJf "$WORK/firefox.tar.xz" -C "$WORK"
test -x "$WORK/firefox/firefox" || {
  echo "[!] Extracted tree has no firefox binary — layout changed upstream?" >&2
  exit 1
}

# Replace rather than merge: a half-overwritten browser tree is worse than a
# missing one. The old tree moves aside and is only deleted once the new one
# has landed, so an interrupted run leaves something recoverable.
mkdir -p "$(dirname "$PREFIX")"
if [ -e "$PREFIX" ]; then
  echo "[*] Replacing the existing install at $PREFIX…"
  rm -rf "$PREFIX.old"
  mv "$PREFIX" "$PREFIX.old"
fi
mv "$WORK/firefox" "$PREFIX"
rm -rf "$PREFIX.old"

echo "[*] Writing $DESKTOP…"
mkdir -p "$APPS_DIR"
# MOZ_APP_REMOTINGNAME does two jobs. It fixes WM_CLASS to a known value so
# StartupWMClass matches and GNOME groups the window under this launcher rather
# than showing a second unnamed icon; and it gives Nightly its own remoting
# name, so `firefox` from a terminal cannot hand a URL to the wrong browser.
cat >"$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Firefox Nightly
GenericName=Web Browser
Comment=Nightly build of Firefox — tracks mozilla-central
Exec=env MOZ_APP_REMOTINGNAME=firefox-nightly $PREFIX/firefox %u
Icon=$PREFIX/browser/chrome/icons/default/default128.png
Terminal=false
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
StartupNotify=true
StartupWMClass=firefox-nightly
EOF

# Non-fatal: the entry works without it, the cache only affects how quickly the
# launcher notices.
update-desktop-database "$APPS_DIR" 2>/dev/null || true

VERSION="$(awk -F= '/^Version=/ { print $2 }' "$PREFIX/application.ini" 2>/dev/null | head -1)"
echo ""
echo "[*] Firefox Nightly ${VERSION:-installed} → $PREFIX"
echo ""
echo "    It updates itself from here — this script is a one-off per host."
echo "    Launch from the GNOME overview, or:"
echo "      $PREFIX/firefox"
echo ""
echo "    Uninstall:"
echo "      rm -rf $PREFIX $DESKTOP"
echo ""
